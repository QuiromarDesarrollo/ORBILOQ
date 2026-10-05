$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$source = 'C:\Users\analistadatos\Downloads\supabase-files.zip'
$snapshot = 'D:\ORBILOQ-restauracion-20261002-170805\datos-verificacion.sql'
$root = 'D:\ORBILOQ-respaldos\storage'
$dest = Join-Path $root 'documentos\importaciones'
$expected = @{}
$inObjects = $false
foreach ($line in [IO.File]::ReadLines($snapshot)) {
    if ($line -match '^COPY storage.objects \((.+)\) FROM stdin;$') {
        $columns = $Matches[1].Split(',').Trim()
        $inObjects = $true
        continue
    }
    if ($inObjects -and $line -eq '\.') { break }
    if (-not $inObjects) { continue }
    $values = $line.Split("`t")
    $bucket = $values[[Array]::IndexOf($columns, 'bucket_id')]
    $name = $values[[Array]::IndexOf($columns, 'name')]
    if ($bucket -ne 'documentos' -or $name -notmatch '^importaciones/[^/\\]+\.xlsx$') {
        throw 'El inventario contiene una ruta no prevista. Revisar antes de extraer.'
    }
    # COPY text doubles JSON backslashes, including escaped quotes in eTag.
    $metadata = $values[[Array]::IndexOf($columns, 'metadata')].Replace('\\', '\') | ConvertFrom-Json
    $expected[$name.Substring('importaciones/'.Length)] = [long]$metadata.size
}
if ($expected.Count -ne 18) { throw 'El inventario no contiene los 18 archivos esperados.' }
$zip = [IO.Compression.ZipFile]::OpenRead($source)
try {
    $seen = @{}
    foreach ($entry in $zip.Entries) {
        if (-not $expected.ContainsKey($entry.FullName) -or $seen.ContainsKey($entry.FullName)) {
            throw 'El ZIP contiene una ruta inesperada o duplicada.'
        }
        if ($entry.Length -ne $expected[$entry.FullName]) { throw 'El tamaño del ZIP no coincide con Storage.' }
        $seen[$entry.FullName] = $true
    }
    $null = New-Item -ItemType Directory -Force -Path $dest
    foreach ($entry in $zip.Entries) {
        $target = Join-Path $dest $entry.FullName
        if (Test-Path -LiteralPath $target) { throw "El archivo ya existe; no se sobrescribe: $($entry.FullName)" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
    }
} finally { $zip.Dispose() }
$records = foreach ($name in ($expected.Keys | Sort-Object)) {
    $path = Join-Path $dest $name
    if (-not (Test-Path -LiteralPath $path)) { throw "Falta archivo: $name" }
    if ((Get-Item -LiteralPath $path).Length -ne $expected[$name]) { throw "Tamaño incorrecto: $name" }
    # Read every worksheet/archive entry to detect unreadable compressed content.
    $xlsx = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        if (-not $xlsx.GetEntry('[Content_Types].xml') -or -not $xlsx.GetEntry('xl/workbook.xml')) {
            throw "No parece un XLSX válido: $name"
        }
        foreach ($part in $xlsx.Entries) {
            $stream = $part.Open()
            try { $stream.CopyTo([IO.Stream]::Null) } finally { $stream.Dispose() }
        }
    } finally { $xlsx.Dispose() }
    [pscustomobject]@{bucket='documentos'; ruta="importaciones/$name"; bytes=$expected[$name]; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
}
$zipCopy = Join-Path $root ('supabase-files-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip')
Copy-Item -LiteralPath $source -Destination $zipCopy
if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $zipCopy).Hash) { throw 'El ZIP copiado no coincide.' }
$manifest = Join-Path $root ('verificacion-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
[ordered]@{
 fecha_utc=[DateTime]::UtcNow.ToString('o'); archivos=$records; total=$records.Count;
 comparacion='Rutas y tamaños contra metadatos del respaldo 2026-10-02; SHA256 locales y lectura de contenido XLSX. No se compararon hashes con el servidor remoto.';
 zip_copia=$zipCopy; zip_sha256=(Get-FileHash -LiteralPath $zipCopy).Hash
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifest -Encoding UTF8
[pscustomobject]@{archivos_verificados=$records.Count; carpeta=$dest; manifiesto=$manifest; zip=$zipCopy} | ConvertTo-Json -Compress
