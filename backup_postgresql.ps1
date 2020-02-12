# Скрипт создания бэкапов PostgreSQl
# минимальная версия PowerShell 5.1. С версией ниже встроенная архивация не работает
# Текущая дата
$date = Get-Date -format "yyyy-MM-dd"
$config = Get-Content config.json | ConvertFrom-Json
$temp_bd_list = $config.path_backup+"temp_bd_list.txt"
# Устанавливаем переменную окружения с данными для подключения к PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
# Устанавливаем рабочий каталог с сиполняемыми файлами PostgreSQL
Set-Location $config.psql_srv.path_bin
# Получаем список БД сервера PostgreSQL
Write-Host "Get list DB in $temp_bd_list"
.\psql.exe -A -q -t -c "select datname from pg_database" > $temp_bd_list
$name_bd_list = get-content $temp_bd_list
# Удаляем временный файл
Remove-Item $temp_bd_list -Recurse
foreach ($name_bd in $name_bd_list) {
    # Проверяем имя БД с системными БД
    if (-not ($config.psql_srv.system_bd -match $name_bd)) {
        # Получаем имя файла архивной копии
        $name_bd_file=$config.path_backup+$date+"_"+$name_bd+".sql"
        # Дамп БД
        Write-Host "Dump $name_bd in $name_bd_file"
        .\pg_dump.exe -Fc -b -f $name_bd_file $name_bd       
    }
}
# Проверяем необходимость сжатия дампа 
if ($config.compress_zip) {
    # Получаем списко файлов для архивации
    $list_file_sql = [IO.Directory]::EnumerateFiles($config.path_backup,'*.sql')
    foreach ($file_sql in $list_file_sql) {
        # Получаем полное полный путь и имя файла SQL
        $full_file_sql = $config.$path_backup+$file_sql
        # Получаем имя сжатого дампа БД
        $zip_name_bd_file=$full_file_sql+".zip"
        Write-Host "Greate arhive $full_file_sql in $zip_name_bd_file"
        # Сжимаем дамп
        Compress-Archive -Path $full_file_sql -DestinationPath $zip_name_bd_file -CompressionLevel Optimal
        # Удаляем не сжатый дамп
        Remove-Item $full_file_sql -Recurse
    }
}
# Удаляем дампы страрше $lifetime_backup
# Вычисляем дату после которой будем удалять файлы.
$CurrentDay = Get-Date
$ChDaysDel = $CurrentDay.AddDays($config.lifetime)
Get-ChildItem -Path $config.path_backup -Recurse | Where-Object { $_.CreationTime -LT $ChDaysDel } | Remove-Item -Recurse -Force