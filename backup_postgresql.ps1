# ������ �������� ������� PostgreSQl
# ����������� ������ PowerShell 5.1. � ������� ���� ���������� ��������� �� ��������
function GetListFTP ($ip, $path, $user, $pass) {
    $file_list = @()
    $ftp = [System.Net.WebRequest]::Create($ip + $path)
    $ftp.Credentials = new-object System.Net.NetworkCredential($user, $pass)
    $ftp.UseBinary = $true
    $ftp.UsePassive = $true
    $ftp.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $FTPResponse = $ftp.GetResponse()
    $ResponseStream = $FTPResponse.GetResponseStream()
    $FTPReader = New-Object System.IO.Streamreader -ArgumentList $ResponseStream
    while ($FTPReader.EndOfStream -ne $true) {
        $file_list += $FTPReader.ReadLine()
    }
    $FTPReader.Close()
    $ResponseStream.Close()
    $Response.Close()
    $ftp.Close()
    $FTPReader.Dispose()
    $ResponseStream.Dispose()
    $Response.Dispose()
    $ftp.Dispose()
    return $file_list
}
function GetDateCreateFileFTP ($ip, $path, $user, $pass, $name) {
    $ftp = [System.Net.FtpWebRequest]::Create($ip + $path + $name)
    $ftp.Credentials = new-object System.Net.NetworkCredential($user, $pass)
    $ftp.UseBinary = $true
    $ftp.UsePassive = $true
    $ftp.Method = [System.Net.WebRequestMethods+Ftp]::GetDateTimestamp
    $FTPResponse = $ftp.GetResponse()
    $date_create = $FTPResponse.LastModified   
    $Response.Close()
    $Response.Dispose()
    $ftp.Close()
    $ftp.Dispose()
    return $date_create
}
function DeleteFileFTP ($ip, $path, $user, $pass, $name) {
    $ftp = [System.Net.FtpWebRequest]::Create($ip + $path + $name)
    $ftp = [System.Net.FtpWebRequest]$ftp
    $ftp.Credentials = new-object System.Net.NetworkCredential($user, $pass)
    $ftp.UseBinary = $true
    $ftp.UsePassive = $true
    $ftp.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    $FTPResponse = $ftp.GetResponse()
    $FTPResponse.Close()
    $FTPResponse.Dispose() 
    $ftp.Close()
    $ftp.Dispose()   
}
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Start script"
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Initilizacion variable"
# ������� ����
$date = Get-Date -format "yyyy-MM-dd"
$config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
$temp_bd_list = $config.path_backup+"temp_bd_list.txt"
# ������������� ���������� ��������� � ������� ��� ����������� � PostgreSQL
$env:PGHOST = $config.psql_srv.ip
$env:PGPORT = $config.psql_srv.port
$env:PGUSER = $config.psql_srv.user
$env:PGPASSWORD = $config.psql_srv.password
# ������������� ������� ������� � ������������ ������� PostgreSQL
Set-Location $config.psql_srv.path_bin
# �������� ������ �� ������� PostgreSQL
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Get list DB in $temp_bd_list"
.\psql.exe -A -q -t -c "select datname from pg_database" > $temp_bd_list
$name_bd_list = get-content $temp_bd_list
# ������� ��������� ����
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Remove temp file list bd"
Remove-Item $temp_bd_list -Recurse -Force
foreach ($name_bd in $name_bd_list) {
    # ��������� ��� �� � ���������� ��
    if (-not ($config.psql_srv.system_bd -match $name_bd)) {
        # �������� ��� ����� �������� �����
        $name_bd_file=$config.path_backup+$date+"_"+$name_bd+".sql"
        # ���� ��
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Dump $name_bd in $name_bd_file"
        .\pg_dump.exe -Fc -b -f $name_bd_file $name_bd       
    }
}
# ��������� ������������� ������ ����� 
if ($config.compress_zip) {
    Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Start create zip arhive"
    # �������� ������ ������ ��� ���������
    $list_file_sql = [IO.Directory]::EnumerateFiles($config.path_backup,'*.sql')
    foreach ($file_sql in $list_file_sql) {
        # �������� ������ ������ ���� � ��� ����� SQL
        $full_file_sql = $config.$path_backup+$file_sql
        # �������� ��� ������� ����� ��
        $zip_name_bd_file=$full_file_sql+".zip"
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Greate arhive $full_file_sql in $zip_name_bd_file"
        # ������� ����
        Compress-Archive -Path $full_file_sql -DestinationPath $zip_name_bd_file -CompressionLevel Optimal
        # ������� �� ������ ����
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Delete file $full_file_sql"
        Remove-Item $full_file_sql -Recurse -Force
    }
}
# ������� ����� ������� $lifetime_backup
# ��������� ���� ����� ������� ����� ������� �����.
Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Delete old file"
$ChDaysDel = $date.AddDays($config.lifetime)
Get-ChildItem -Path $config.path_backup -Recurse | Where-Object { $_.CreationTime -LT $ChDaysDel } | Remove-Item -Recurse -Force
#�������� �� FTP
if ($config.FTP.true) {
    $list_files = [IO.Directory]::EnumerateFiles($config.path_backup, "$date*")
    $ftp = New-Object System.Net.WebClient
    $ftp.NetworkCredential = New-Object System.Net.NetworkCredential($config.FTP.user, $config.FTP.password)
    foreach ($name_file in $list_files) {
        $uri = "ftp://"+$config.FTP.ip+$config.FTP.path+$name_file   
        $file = $config.path_backup+$name_file
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Start copy file $name_file to FTP"
        $ftp.UploadFile($uri, $file)
        Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Finish copy file $name_file to FTP"
    }
    $ftp.Dispose()
    # ������� ������ ����� � FTP
    # �������� ������ ������ �� FTP
    Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Get list file FTP"
    $file_list_ftp = GetListFTP -ip $config.FTP.ip -patp $config.FTP.path -user $config.FTP.user -pass $config.FTP.password
    foreach ($file_name_ftp in $file_list_ftp) {
        $DateCreateFileFTP = GetDateCreateFileFTP -ip $config.FTP.ip -patp $config.FTP.path -user $config.FTP.user -pass $config.FTP.password -name $file_name_ftp
        if ($DateCreateFileFTP -LT $data.AddDays($config.FTP.lifetime)){
            Write-Host $(Get-Date -format "yyyy-MM-dd HH:mm") "Delete file $file_name_ftp in FTP "
            DeleteFileFTP -ip $config.FTP.ip -patp $config.FTP.path -user $config.FTP.user -pass $config.FTP.password -name $file_name_ftp
        }
    }

}