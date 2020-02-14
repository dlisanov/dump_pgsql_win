# Скрипто восстановления БД PostgreSQL в новую чистую базу
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
    $ftp.Credentials = New-Object System.Net.NetworkCredential($user, $pass)
    $uri = New-Object System.Uri($link)      
    $ftp.DownloadFile($uri, $file)    
}
$config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
# Иницилизируем переменные окружения PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
$type_repo = Read-Host "Enter type repositary backup (local/ftp) [local]"
# Получаем список бэкапов
$list_backup=@()
switch ($type_repo) {
    "ftp" { $list_backup = GetListFTPBackup -ip $config.FTP.ip -path $config.FTP.path -user $config.FTP.user -pass $config.FTP.password }
    Default { $list_backup = GetListLocalBackup -path $config.path_backup }
}
# Выводи списко бэкапов с номерами
$i = 1
foreach ($name_bakup in $list_backup) {
    Write-Host "$i - $name_bakup"
    $i += 1
}
$num_backup = Read-Host "Enter number backup"
$num_backup = $num_backup - 1
# Загружаем бэкап с FTP
if ($type_repo -eq "ftp") {
    $full_name_backup = $config.path_backup + "FTP_" + $list_backup[$num_backup]
    $link = $config.FTP.ip + $config.FTP.path + $list_backup[$num_backup]
    DownloadFTPFile -link $link -user $config.FTP.user -pass $config.FTP.password -file $full_name_backup
}
else {
    $full_name_backup = $config.path_backup + $list_backup[$num_backup]
}
# Распаковываем архив
if ($full_name_backup.Contains(".zip")){
    Expand-Archive -LiteralPath $full_name_backup -DestinationPath $config.path_backup
    $full_name_backup = $full_name_backup.Substring(0, ($full_name_backup.Length)-4)
}
# Запрашиваем имя новой БД для создания и последующей загрузки
$name_bd = Read-Host "Enter name new database"
# Переходим в каталог PostgreSQL
Set-Location $config.psql_srv.path_bin
# Создаем пустую БД
.\createdb.exe -E "UTF8" -l "Russian_Russia.1251" $name_bd
# Восстанавливаем БД в созданую базу
.\pg_restore.exe --dbname "$name_bd" --section=pre-data --section=data --section=post-data "$full_name_backup" 