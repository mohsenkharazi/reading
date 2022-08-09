#Provide SQLServerName
$SQLServer = "10.0.2.4"
#Provide Database Name 
$DatabaseName = "pdb_ccms"
#Scripts Folder Path
$TblFolderPath ="./Tables"
$TrgFolderPath ="./Triggers"
$ProcFolderPath ="./Procedures"
$DataFolderPath ="./Master Data Insertion"
#Database Username
$DbUserName = ""
#Database Password
$DbPassword = ""

#Loop through the .sql files in tables folder and run them
foreach ($filename in get-childitem -path $TblFolderPath -filter "*.sql")
{
invoke-sqlcmd -ServerInstance $SQLServer -Database $DatabaseName -username $DbUserName -password $DbPassword -InputFile $filename.fullname
#Print file name which is executed
$filename 
} 

#Loop through the .sql files in triggers folder and run them
foreach ($filename in get-childitem -path $TrgFolderPath -filter "*.sql")
{
invoke-sqlcmd -ServerInstance $SQLServer -Database $DatabaseName -username $DbUserName -password $DbPassword -InputFile $filename.fullname
#Print file name which is executed
$filename 
} 

#Loop through the .sql files in procedures folder and run them
foreach ($filename in get-childitem -path $ProcFolderPath -filter "*.sql")
{
invoke-sqlcmd -ServerInstance $SQLServer -Database $DatabaseName -username $DbUserName -password $DbPassword -InputFile $filename.fullname
#Print file name which is executed
$filename 
} 

#Loop through the .sql files in master data insertion folder and run them
foreach ($filename in get-childitem -path $DataFolderPath -filter "*.sql")
{
invoke-sqlcmd -ServerInstance $SQLServer -Database $DatabaseName -username $DbUserName -password $DbPassword -InputFile $filename.fullname
#Print file name which is executed
$filename 
} 



