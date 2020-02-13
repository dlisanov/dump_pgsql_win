# ������ �������������� �� PostgreSQL
# ��������� ������
$config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
# ������������� ���������� ��������� ��� PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
# ��������� � ������� � ������������ ������� PostgreSQL
#Set-Location $config.psql_srv.path_bin
$type_repo = Read-Host "����� ������� (local/ftp) [local]"
<#if (($type_repo -ne "ftp") -and ($type_repo -ne "local")) {
    $type_repo = "local"
}#>
switch ($type_repo) {
    "ftp" { "1" }
    Default {"2"}
}