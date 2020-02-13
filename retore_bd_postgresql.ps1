# ������ �������������� �� PostgreSQL
# ��������� ������
function GetListLocalBackup ($path) {
    $file_list = Get-ChildItem -Path $path
    return $file_list.Name    
}
$config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
# ������������� ���������� ��������� ��� PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
# ��������� � ������� � ������������ ������� PostgreSQL
#Set-Location $config.psql_srv.path_bin
$type_repo = Read-Host "����� ������� (local/ftp) [local]"

switch ($type_repo) {
    "ftp" { "1" }
    Default {GetListLocalBackup -path $config.path_backup}
}