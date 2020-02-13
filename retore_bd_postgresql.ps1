# Скрипт восстановления БД PostgreSQL
# Загружаем конфиг
$config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
# Иницилизируем переменные окружения для PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
# Переходим в каталог с исполняемыми файлами PostgreSQL
#Set-Location $config.psql_srv.path_bin
$type_repo = Read-Host "Поиск бэкапов (local/ftp) [local]"
<#if (($type_repo -ne "ftp") -and ($type_repo -ne "local")) {
    $type_repo = "local"
}#>
switch ($type_repo) {
    "ftp" { "1" }
    Default {"2"}
}