# Скрипт создания бэкапов PostgreSQl
# минимальная версия PowerShell 5.1. С версией ниже встроенная архивация не работает
# Текущая дата
$date = Get-Date -format "yyyy-MM-dd"
# IP сервера Postgresql
$ip_psql="192.168.0.20"
# Пользователь для подключения к PostgreSQL
$user_psql="postgres"
# Пароль пользователя для подключения к PostgreSQL
$user_pass_psql="Password1"
# Каталог исполняемых файлов PostgreSQL
$path_psql="d:\progremmers\PosqtgreSQL\App\PgSQL\bin\"
# Каталог архивных копий БД PostgreSQL
$path_backup="d:\1c_backup\"
# Имя временного файла списка баз серевера PostgreSQL
$temp_bd_list=$path_backup+"temp_bd_list.txt"
# Список системных БД PostgreSQL
$system_bd_psql=@("postgres","template1","template0")
# Сжатие файлов архивных копий БД ($true - сжимать, $false - не сжимать)
$compress_zip=$true
# Время жизни файла бэкапа
$lifetime_backup="-5"
# Устанавливаем переменную окружения с паролем пользователя
$env:PGPASSWORD=$user_pass_psql
# Устанавливаем рабочий каталог с сиполняемыми файлами PostgreSQL
Set-Location $path_psql
# Получаем список БД сервера PostgreSQL
.\psql.exe -h $ip_psql -U $user_psql -A -q -t -c "select datname from pg_database" > $temp_bd_list
$name_bd_list = get-content $temp_bd_list
# Удаляем временный файл
Remove-Item $temp_bd_list -Recurse
foreach ($name_bd in $name_bd_list) {
    # Проверяем имя БД с системными БД
    if (-not ($system_bd_psql -match $name_bd)) {
        # Получаем имя файла архивной копии
        $name_bd_file="$path_backup$date_$name_bd.sql"
        # Дамп БД
        echo ".\pg_dump.exe -h $ip_psql -U $user_psql -Fc -b -f $name_bd_file $name_bd "
        # Проверяем необходимость сжатия дампа
        #if ($compress_zip) {
            # Получаем имя сжатого дампа БД
         #   $zip_name_bd_file="$name_bd_file.zip"
            # Сжимаем дамп
          #  Compress-Archive -Path $name_bd_file -DestinationPath $zip_name_bd_file -CompressionLevel Optimal
            # Удаляем не сжатый дамп
           # Remove-Item $name_bd_file -Recurse
        #}
    }
}
# Удаляем дампы страрше $lifetime_backup
# Вычисляем дату после которой будем удалять файлы.
#$CurrentDay = Get-Date
#$ChDaysDel = $CurrentDay.AddDays($lifetime_backup)
#GCI -Path $path_backup-Recurse | Where-Object {$_.CreationTime -LT $ChDaysDel} | RI -Recurse -Force
