param(
  [Parameter(Mandatory=$true)][string]$InformePruebas,
  [string]$Salida = '.dart_tool/sql-test/fixture.sql'
)
$ErrorActionPreference = 'Stop'
$rows = Import-Csv -LiteralPath $InformePruebas
function Section($name) { @(($rows | Where-Object seccion -eq $name).detalle_json | ConvertFrom-Json) }
function Q($name) { '"' + $name.Replace('"', '""') + '"' }
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;')
$lines.Add('CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting(''request.jwt.claim.sub'',true),'''')::uuid $$; GRANT USAGE ON SCHEMA auth TO authenticated,anon; GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated,anon;')
foreach ($seq in (Section '14_secuencias_configuracion')) {
  $s = $seq.detalle
  $lines.Add('CREATE SEQUENCE public.' + (Q $s.nombre) + ' START ' + $s.inicio + ';')
}
$cols = Section '03_columnas'
foreach ($rel in (Section '02_relaciones' | Where-Object { $_.detalle.tipo -eq 'r' })) {
  $name = $rel.detalle.nombre
  $defs = foreach ($col in ($cols | Where-Object { $_.detalle.tabla -eq $name } | Sort-Object { $_.detalle.posicion })) {
    $c = $col.detalle
    $def = (Q $c.columna) + ' ' + $c.tipo
    if ($c.default_o_expresion) { $def += ' DEFAULT ' + $c.default_o_expresion }
    if ($c.no_nulo) { $def += ' NOT NULL' }
    $def
  }
  $lines.Add('CREATE TABLE public.' + (Q $name) + '(' + ($defs -join ',') + ');')
  if ($rel.detalle.rls_habilitado) { $lines.Add('ALTER TABLE public.' + (Q $name) + ' ENABLE ROW LEVEL SECURITY;') }
}
# Claves primarias/unicas antes de las claves foraneas.
foreach ($constraint in (Section '04_restricciones' | Sort-Object { if ($_.detalle.tipo -eq 'f') { 1 } else { 0 } })) {
  $c = $constraint.detalle
  $lines.Add('ALTER TABLE public.' + $c.tabla + ' ADD CONSTRAINT ' + (Q $c.nombre) + ' ' + $c.definicion + ';')
}
foreach ($view in (Section '06_vistas' | Where-Object { $_.detalle.nombre -in @('vista_kardex','vista_stock_ubicacion_detalle') })) {
  $lines.Add('CREATE VIEW public.' + (Q $view.detalle.nombre) + ' AS ' + $view.detalle.definicion)
}
foreach ($routine in (Section '07_funciones_y_procedimientos')) { $lines.Add($routine.detalle.definicion + ';') }
foreach ($policy in (Section '09_politicas_rls')) {
  $p = $policy.detalle
  if ($p.comando -ne '*') { throw 'Fixture solo soporta las politicas ALL del informe DEV.' }
  $lines.Add('CREATE POLICY ' + (Q $p.nombre) + ' ON public.' + (Q $p.tabla) + ' FOR ALL TO authenticated USING (' + $p.using + ') WITH CHECK (' + $p.with_check + ');')
}
$lines.Add('GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated; GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;')
Set-Content -LiteralPath $Salida -Value ($lines -join "`n") -Encoding utf8
Write-Output ('Fixture creada: ' + $Salida)
