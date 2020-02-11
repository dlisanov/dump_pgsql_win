# Скрипт создания бэкапов PostgreSQl
# минимальная версия PowerShell 5.1. С версией ниже встроенная архивация не работает
# Текущая дата
$date = Get-Date -format "yyyy-MM-dd"
$config = Get-Content config.json | ConvertFrom-Json
$temp_bd_list = $config.path_backup+$date+"temp_bd_list.txt"
# Устанавливаем переменную окружения с данными для подключения
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
# Устанавливаем рабочий каталог с сиполняемыми файлами PostgreSQL
Set-Location $config.psql_srv.path_bin
# Получаем список БД сервера PostgreSQL
.\psql.exe -A -q -t -c "select datname from pg_database" > $temp_bd_list
$name_bd_list = get-content $temp_bd_list
# Удаляем временный файл
Remove-Item $temp_bd_list -Recurse
foreach ($name_bd in $name_bd_list) {
    # Проверяем имя БД с системными БД
    if (-not ($config.psql_srv.system_bd -match $name_bd)) {
        # Получаем имя файла архивной копии
        $name_bd_file=$path_backup+$date+"_"+$name_bd+".sql"
        # Дамп БД
        .\pg_dump.exe -Fc -b -f $name_bd_file $name_bd
        # Проверяем необходимость сжатия дампа
        if ($config.compress_zip) {
            $PSVersionTable.PSVersion.MajorRevision
            #Получаем имя сжатого дампа БД
            $zip_name_bd_file=$name_bd_file+".zip"
            # Сжимаем дамп
            Compress-Archive -Path $name_bd_file -DestinationPath $zip_name_bd_file -CompressionLevel Optimal
            # Удаляем не сжатый дамп
            Remove-Item $name_bd_file -Recurse
        }
    }
}
# Удаляем дампы страрше $lifetime_backup
# Вычисляем дату после которой будем удалять файлы.
$CurrentDay = Get-Date
$ChDaysDel = $CurrentDay.AddDays($config.lifetime)
Get-ChildItem -Path $path_backup-Recurse | Where-Object { $_.CreationTime -LT $ChDaysDel } | Remove-Item -Recurse -Force