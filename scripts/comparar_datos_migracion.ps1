param(
 [Parameter(Mandatory=$true)][string]$Antes,
 [Parameter(Mandatory=$true)][string]$Despues,
 [Parameter(Mandatory=$true)][string]$Informe,
 [switch]$PermitirBucketSeguimiento
)
$ErrorActionPreference='Stop'
function Read-CopyBlocks([string]$path) {
 $tables=@{}
 $table=$null
 foreach($line in [IO.File]::ReadLines($path)) {
  if($line -match '^COPY (.+?) \((.+)\) FROM stdin;$') {
   $table=$Matches[1]
   $tables[$table]=@{columnas=$Matches[2].Split(',').Trim();filas=[Collections.Generic.List[string]]::new()}
  } elseif($line -eq '\.') { $table=$null }
  elseif($null -ne $table) { $tables[$table].filas.Add($line) }
 }
 return $tables
}
function Rows-Hash([string[]]$rows) {
 [Array]::Sort($rows,[StringComparer]::Ordinal)
 $sha=[Security.Cryptography.SHA256]::Create()
 try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]::Join("`n",$rows)))).Replace('-','') }
 finally { $sha.Dispose() }
}
$a=Read-CopyBlocks $Antes
$b=Read-CopyBlocks $Despues
$results=foreach($table in ($a.Keys|Sort-Object)) {
 if(-not $b.ContainsKey($table)){throw "Tabla ausente: $table"}
 $indices=@($a[$table].columnas|ForEach-Object {[Array]::IndexOf($b[$table].columnas,$_ )})
 if($indices -contains -1){throw "Columna original ausente en $table"}
 $projected=[Collections.Generic.List[string]]::new()
 foreach($line in $b[$table].filas) {
  $cells=$line.Split("`t")
  if ($PermitirBucketSeguimiento -and $table -eq 'storage.buckets') {
   $idIndex=[Array]::IndexOf($b[$table].columnas,'id')
   if ($idIndex -lt 0) { throw 'Falta ID de bucket' }
   if ($cells[$idIndex] -eq 'seguimiento-evidencias') {
    $oldIdIndex=[Array]::IndexOf($a[$table].columnas,'id')
    if (@($a[$table].filas | Where-Object { $_.Split("`t")[$oldIdIndex] -eq 'seguimiento-evidencias' }).Count) { throw 'El bucket de seguimiento ya existía; no permitir excepción' }
    $publicIndex=[Array]::IndexOf($b[$table].columnas,'public')
    $limitIndex=[Array]::IndexOf($b[$table].columnas,'file_size_limit')
    if ($publicIndex -lt 0 -or $limitIndex -lt 0 -or $cells[$publicIndex] -ne 'f' -or $cells[$limitIndex] -ne '10485760') { throw 'Configuración inesperada del nuevo bucket' }
    continue
   }
  }
  $projected.Add([string]::Join("`t",[string[]]@($indices|ForEach-Object {$cells[$_]})))
 }
 $originalHash=Rows-Hash $a[$table].filas.ToArray()
 $newHash=Rows-Hash $projected.ToArray()
 [pscustomobject]@{tabla=$table;filas_antes=$a[$table].filas.Count;filas_despues=$projected.Count;columnas_originales=$indices.Count;sha256_antes=$originalHash;sha256_despues=$newHash;coincide=($originalHash -ceq $newHash -and $a[$table].filas.Count -eq $projected.Count)}
}
$results|Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $Informe
[pscustomobject]@{tablas=$results.Count;tablas_identicas=@($results|Where-Object coincide).Count;filas_originales=($results|Measure-Object filas_antes -Sum).Sum;alta_bucket_seguimiento_permitida=[bool]$PermitirBucketSeguimiento;diferencias=@($results|Where-Object {-not $_.coincide}|ForEach-Object tabla)}|ConvertTo-Json -Compress
if(@($results|Where-Object {-not $_.coincide}).Count){throw 'Existen diferencias: revisar el informe antes de publicar.'}
