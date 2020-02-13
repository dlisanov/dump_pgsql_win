# Скрипт создания бэкапов (дампов) БД PostgreSQl для 1с
# Для работы скрипта необходим минимум PowerShell 5.1, если предыдущая версию нужно установить обновления
function GetListFTP ($ip, $path, $user, $pass) {
    $file_list = @()
    $ftp = [System.Net.WebRequest]::Create("$ip$path")
    $ftp.Credentials = new-object System.Net.NetworkCredential($user, $pass)
    $ftp.UseBinary = $true
    $ftp.UsePassive = $true
    $ftp.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $FTPResponse = $ftp.GetResponse()
    $ResponseStream = $FTPResponse.GetResponseStream()
    $FTPReader = New-Object System.IO.Streamreader -ArgumentList $ResponseStream
    while ($null -ne ($string = $FTPReader.ReadLine())) {
        $file_list += $string
    }
    return $file_list
}
function GetDateCreateFileFTP ($ip, $path, $user, $pass, $name) {
    $ftp = [System.Net.FtpWebRequest]::Create("$ip$path$name")
    $ftp.Credentials = new-object System.Net.NetworkCredential($user, $pass)
    $ftp.UseBinary = $true
    $ftp.UsePassive = $true
    $ftp.Method = [System.Net.WebRequestMethods+Ftp]::GetDateTimestamp
    $FTPResponse = $ftp.GetResponse()
    $date_create = $FTPResponse.LastModified
    return $date_create
}
function DeleteFileFTP ($ip, $path, $user, $pass, $name) {
    $ftp = [System.Net.FtpWebRequest]::Create("$ip$path$name")
    $ftp.Credentials = new-object System.Net.NetworkCredential($user, $pass)
    $ftp.UseBinary = $true
    $ftp.UsePassive = $true
    $ftp.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    $FTPResponse = $ftp.GetResponse()
    $FTPResponse.Dispose() 
    $ftp.Dispose   
}
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Start script"
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Initilizacion variable"
# Получаем текущую дату и дату нужного формата
$current_date = Get-Date 
$date = Get-Date -format "yyyy-MM-dd"
# Загружаем конфиг
$config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
$temp_bd_list = $config.path_backup+"temp_bd_list.txt"
# Иницилизируем переменные окружения для PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
# Переходим в каталог с исполняемыми файлами PostgreSQL
Set-Location $config.psql_srv.path_bin
# Получаем списко БД PostgreSQL
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Get list DB in $temp_bd_list"
.\psql.exe -A -q -t -c "select datname from pg_database" > $temp_bd_list
$name_bd_list = get-content $temp_bd_list
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Remove temp file list bd"
Remove-Item $temp_bd_list -Recurse -Force
# Запускаем создание бэкапов БД
foreach ($name_bd in $name_bd_list) {
    # Проверяем наличие имени БД списке системных
    if (-not ($config.psql_srv.system_bd -match $name_bd)) {
        # Полное имя файла бэкапа
        $name_bd_file=$config.path_backup+$date+"_"+$name_bd+".sql"
        # Делаем бэкап БД
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Dump $name_bd in $name_bd_file"
        .\pg_dump.exe -Fc -b -f $name_bd_file $name_bd       
    }
}
# Сжимаем бэкапы 
if ($config.compress_zip) {
    Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Start create zip arhive"
    # Список всех не сжатых бэкапов
    $list_file_sql = [IO.Directory]::EnumerateFiles($config.path_backup,'*.sql')
    foreach ($file_sql in $list_file_sql) {
        # Полное имя zip архива
        $zip_name_bd_file=$file_sql+".zip"
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Greate arhive $file_sql in $zip_name_bd_file"
        # Сжимаем файл
        Compress-Archive -Path $file_sql -DestinationPath $zip_name_bd_file -CompressionLevel Optimal
        # Удаляем исходный файл
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Delete file $full_file_sql"
        Remove-Item $full_file_sql -Recurse -Force
    }
}
# Удалем старые бэкапы
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Delete old file"
$ChDaysDel = $current_date.AddDays($config.lifetime)
Get-ChildItem -Path $config.path_backup -Recurse | Where-Object { $_.CreationTime -LT $ChDaysDel } | Remove-Item -Recurse -Force

# Копируем на FTP при небходимости
if ($config.FTP.true) {
    # Список файлов для копирования на FTP
    $list_files = Get-ChildItem -Path $config.path_backup | Where-Object { $_.Name -match "$date" }
    # Иницилизируем переменную для работы с FTP
    $ftp = New-Object System.Net.WebClient
    $ftp.Credentials = New-Object System.Net.NetworkCredential($config.FTP.user, $config.FTP.password)
    foreach ($name_file in $list_files.Name) {
        # URL для загрузки файла
        $uri = New-Object System.Uri($config.FTP.ip+$config.FTP.path+$name_file)  
        $file = $config.path_backup+$name_file
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Start copy file $name_file to FTP"
        $ftp.UploadFile($uri, $file)
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Finish copy file $name_file to FTP"
    }
    $ftp.Dispose()
    # Удаляем старые файлы на FTP
    Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Get list file FTP"
    # Получаем списко файлов на FTP
    $file_list_ftp = GetListFTP -ip $config.FTP.ip -path $config.FTP.path -user $config.FTP.user -pass $config.FTP.password
    foreach ($file_name_ftp in $file_list_ftp) {
        # Получаем дату создания файла на FTP
        $DateCreateFileFTP = GetDateCreateFileFTP -ip $config.FTP.ip -path $config.FTP.path -user $config.FTP.user -pass $config.FTP.password -name $file_name_ftp
        $date_delete_ftp = $current_date.AddDays($config.FTP.lifetime)
        if ($DateCreateFileFTP -lt $date_delete_ftp){
            Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Delete file $file_name_ftp in FTP "
            DeleteFileFTP -ip $config.FTP.ip -path $config.FTP.path -user $config.FTP.user -pass $config.FTP.password -name $file_name_ftp
        }
    }
}