#################################################################################
# Script for monitoring of free space for two Oracle databases
# Run 32-bit version of PowerShell from C:\Windows\SysWOW64\WindowsPowerShell\v1.0
#################################################################################
#   File    : db_space_check.config.xml                     
#   Purpose : provide settings for the db_space_check.ps1 script       
#################################################################################

# Read XML file

$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
[xml]$XmlDocument = Get-Content -Path "$($scriptPath)\db_space_check.config.xml"

$from       ="Robot <dontreply@mail.com>" 
$subject    ="Database Alert"
$smtpserver ="mailhost.bzwint.com"

# Check space for each database
foreach ($db in $XmlDocument.SelectNodes("//Database"))
###############################################################
{
#############################
# Connection to the database
#############################
$out=""
$connectionString = "Data Source=",$db.dbName,"; User Id=",$db.dbUser,"; Password=",$db.dbPassword,"; Integrated Security=no" -join ""
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Data.OracleClient")
$connection = New-Object System.Data.OracleClient.OracleConnection($connectionString)
$queryString = "SELECT 
 TRUNC((SELECT sum(bytes) from dba_free_space where tablespace_name = 'TXL_LOB') / 
       (SELECT sum(bytes) from dba_data_files where tablespace_name = 'TXL_LOB') *100) AS result FROM DUAL"
$command = new-Object System.Data.OracleClient.OracleCommand($queryString, $connection)
$connection.Open()
$out = $command.ExecuteScalar()
$connection.Close()

write-host $(get-date) "The database" $db.dbName "has",$out,"% of free space" -ForegroundColor DarkGreen

#############################
# Data comparision
#############################
if ($out -eq "") {
# Send Error Mail
  $message="Error with connection to the database!!! ",$db.dbName -join ""
  $body = ($message |out-string)
  [string[]]$To = $db.MailRecipients.Split(',')
  Send-MailMessage -SmtpServer $smtpserver -To $to -From $from -Subject $subject -Body $body -Priority High
  Write-host "Error with connection to the database!!!" $db.dbName -ForegroundColor Red
                }
Else  {
  if ($out -lt $db.Threshold)
         {
# Send Alert Mail
  $message="The database ",$db.dbName, " has less than ",$out, "% of free space!!!" -join ""
  $body = ($message |out-string)
  [string[]]$To = $db.MailRecipients.Split(',')
  Send-MailMessage -SmtpServer $smtpserver -To $to -From $from -Subject $subject -Body $body -Priority High
  Write-host "Alert mail was sent for database" $db.dbName -ForegroundColor DarkYellow
         }
      }
###############################################################
}