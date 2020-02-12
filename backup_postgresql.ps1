# ������ �������� ������� PostgreSQl
# ����������� ������ PowerShell 5.1. � ������� ���� ���������� ��������� �� ��������
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
$CurrentDay = Get-Date
$ChDaysDel = $CurrentDay.AddDays($config.lifetime)
Get-ChildItem -Path $config.path_backup -Recurse | Where-Object { $_.CreationTime -LT $ChDaysDel } | Remove-Item -Recurse -Force