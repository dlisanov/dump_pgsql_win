# Скрипт восстановления БД PostgreSQL
# Загружаем конфиг
function GetListLocalBackup ($path) {
    $file_list = Get-ChildItem -Path $path
    return $file_list.Name    
}
function GetListFTPBackup ($ip, $path, $user, $pass) {
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
function DownloadFTPFile ($link, $user, $pass, $file) {
    $ftp = New-Object System.Net.WebClient
    $ftp.Credentials = New-Object System.Net.NetworkCredential($config.FTP.user, $config.FTP.password)
    $uri = New-Object System.Uri($link)      
    $ftp.UploadFile($uri, $file)    
}
$config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
# Иницилизируем переменные окружения для PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
$type_repo = Read-Host "Поиск бэкапов (local/ftp) [local]"
# Получаем списко бэкапов
$list_backup=@()
switch ($type_repo) {
    "ftp" { $list_backup = GetListFTPBackup -ip $config.FTP.ip -path $config.FTP.path -user $config.FTP.user -pass $config.FTP.password }
    Default { $list_backup = GetListLocalBackup -path $config.path_backup }
}
# Выводим и запрашиваем нужный бэкап
$i = 1
foreach ($name_bakup in $list_backup) {
    Write-Host "$i - $name_bakup"
    $i += 1
}
$num_backup = Read-Host "Введите номер бекапа"
$num_backup = $num_backup - 1
# Получаем полное имя файл бэкапа, при небходимости скачиваем с FTP
if ($type_repo -eq "ftp") {
    $full_name_backup = $config.path_backup + "FTP_" + $list_backup[$num_backup]
    $link = $config.FTP.ip + $config.FTP.path + $list_backup[$num_backup]
    DownloadFTPFile -link $link -user $config.FTP.user -pass $config.FTP.password -file $full_name_backup
}
else {
    $full_name_backup = $config.path_backup + $list_backup[$num_backup]
}
# Распоковываем архив
if ($full_name_backup.Contains(".zip")){
    Expand-Archive -LiteralPath $full_name_backup -DestinationPath $config.path_backup
    $full_name_backup = $full_name_backup.Substring(0, $full_name_backu.Length-4)
}
# Запрашиваем имя БД для восстановления
$name_bd = Read-Host "Введите имя БД, для загрузки данных (БД будет создана)"
# Переходим в каталог с исполняемыми файлами PostgreSQL
Set-Location $config.psql_srv.path_bin
# Создаем пустую бд
.\createdb.exe -E "UTF8" -l "Russian_Russia.1251" $name_bd
# Загружаем данные в БД
.\pg_restore.exe -c -d $name_bd $full_name_backup 