#Requires -Version 3 
#Requires -RunAsAdministrator

<#
    Author Name: Raydi H. //rjh

    Requirements - Powershell / Must be run on locally on Event Log Analyzer

    .NAME 
    DeleteFilesOlder.ps1


    .SYNOPSIS
    Searches a directory for files older than a certain date a deletes the files and folders.  If there isn't more then 5 folders to delete it does not run.

    .Description
    Stops the Services - Eventloganalyzer
    Deletes files and folders in "D:\ManageEngine\EventLog Analyzer\ES\data\ELA-C1\nodes\0\indices"
    Starts the Services - Eventloganalyzer


    .EXAMPLE
    DeleteFilesOlder.ps1 

    .EXAMPLE
    DeleteFilesOlder.ps1  -workingLocation "D:\Clean UpScript" -Logfile "Cleanup.log"
 
    .EXAMPLE
    DeleteFilesOlder.ps1  -workingLocation "D:\Clean UpScript" -Logfile "Cleanup.log" -DaysBack 4

    .PARAMETER Logfile
    You can create a name for your log file or leave the default which is "Cleanup.log" 

    .PARAMETER DaysBack
    This is the amount of days you want to save.  Any file older than X days will be deleted. The default for this is "4"
    Which means that 5+ days will be deleted

    .PARAMETER workingLocation
    This is where the file outputs to and should be where you are running this from.  The default is ".\CleanUpScript"

    .NOTES
    Change Log:
    1.0 New Script //rjh
    1.1 Added a little more detail //eja
    1.2 Changed name to "DeleteFilesOlder-Indices.ps1" and added more detail //eja
    1.3 Added function to deal with the services. //eja
    1.4 Corrected the f_serviceControl function //eja
    1.5 A number of changes to combine tasks //eja
    1.6 Much more clean up and added Recovered amount //eja
    2.0 Removed aliases and made code more vobose.  
 
#>


# Parameters
[CmdletBinding()]
param(
  [String]$workingLocation = '.\CleanUpScript',
  [String]$Logfile='Cleanup.log',
  [Int]$DaysBack = 4
) 

# User Settings
#<><><><><><><><><><><><><><><><><><><>

# Sets Path for file deletion
$Script:path = 'D:\ManageEngine\EventLog Analyzer\ES\data\ELA-C1\nodes\0\indices'
 
# Set date of when files will be deleted before.  
# Amount of days to keep.  Delete all files older than X days back.
$Script:dayLimit = $DaysBack

# Service Name
$Script:Service = Get-Service -Name Eventloganalyzer  #Future option make this a null option in cases that it does not need to be stopped.

$ScriptName = $MyInvocation.MyCommand.Name
#<><><><><><><><><><><><><><><><><><><>

# Create Event
#New-EventLog -LogName "PS Test Log" -Source $ScriptName

#Functions 
#------------

# Test if the script is "RunasAdminsitrator"
$asAdmin = ([Security.Principal.WindowsPrincipal] `
  [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function f_fileTest{

  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    [Object]$Outputfile
  )
  if(!(test-path -Path $Outputfile)){New-Item -Path $Outputfile -ItemType file -Force}
}
function f_foldTest{

  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    [Object]$Outputfold
  )
  if(!(test-path -Path $Outputfold)){New-Item -Path $Outputfold -ItemType Directory -Force}
}

# Creates a unique name for the log file
function f_tdFILEname {
  #$t = Get-Date -uformat "%y%m%d%H%M" # 1703162145 YYMMDDHHmm
    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    [Object]$baseNAME
  )
  $t = Get-Date -uformat '%Y%m%d' # 20170316 YYYYMMDD
  #$t = Get-Date -uformat "%d%H%M%S" # 16214855 DDHHmmss
  #$t = Get-Date -uformat "%y/%m/%d_%H:%M" # 17/03/16_21:52
  return $baseNAME + '-'+ $t + '.log'
}

# Time Stamp
Function f_TimeStamp(){
  # 10/27/2017 21:52:34 (This matches the output for "Date Deleted to" to help readablity
  $Script:TimeStamp = Get-Date -uformat '%m/%d/%y %H:%M:%S'
  return $TimeStamp
}

# Stops and starts services
Function f_serviceControl{

  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    [Object]$Service,

    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    $state
  )
  Write-Debug -Message 'ServiceControl'
  if($state -eq 'Stop'){
    Stop-Service -InputObject $Service #-WhatIf
  }
  if($state -eq 'Start'){
    Start-Service -InputObject $Service #-WhatIf
  }
}


# Output File
# Create the output file and setup the output
function f_Output{
  #Write-EventLog -LogName "PS Test Log" -Source "My Script" -EntryType Information -EventID 100 -Message "This is a test message."

  #if(!(test-path $Outputfile)){New-Item $Outputfile -type file -Force}
    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    $Outputfile,

    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    $strtTime,

    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    $stopTime
  )
  '===================================' | Out-File -FilePath $Outputfile -Append
  ('Start Time: {0}' -f $strtTime) | Out-File -FilePath $Outputfile -Append
  #"Amount of days to save: $dayLimit" | Out-File $Outputfile -Append
  ('Deleted files created before: {0}' -f $limit) | Out-File -FilePath $Outputfile -Append

  if($fileCount -gt 4){
    ('Folders deleted: {0}' -f $fileCount) | Out-File -FilePath $Outputfile -Append
    ('Space recovered: {0} GB' -f $spaceRecovered) | Out-File -FilePath $Outputfile -Append
  }
  # Elapsed Time
  ('Elapsed Time: {0} seconds' -f ($stopTime-$strtTime).totalseconds) | Out-File -FilePath $Outputfile -Append
  #"Working Stop Time - $stopTime" | Out-File $Outputfile -Append
  "Run by: $env:USERNAME" | Out-File -FilePath $Outputfile -Append

}

# Delete files and folders
function f_deleteFileFold(){
  $bforSum = f_fileMath -r 'sum'
  Get-ChildItem -Directory -Path $path -Recurse | Where-Object CreationTime -lt $limit #| Remove-Item -Force -Recurse  -WhatIf
  $aftrSum = f_fileMath -r 'sum'
  $Script:spaceRecovered = ($bforSum.sum + $aftrSum.sum)/1GB
}

function f_fileMath{

  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Add help message for user')]
    $r
  )
  if ($r -eq 'cnt'){
    # Count
    (Get-ChildItem -Directory -Path $path | Where-Object CreationTime -lt $limit).count
  }
  else{
    # if ($r -eq "sum"){}
    Get-ChildItem -Path $path -Recurse | Measure-Object -Property Length -Sum
  }
}


#
#
#  
# Begin Script
# ========================

if ($asAdmin -ne $true){

  # Set working and log location
  f_foldtest -Outputfold $workingLocation
  Set-Location -Path $workingLocation

  # Set name of file
  f_fileTest -Outputfile $Logfile
  $Script:Outputfile = $Logfile


  # Math
  $Script:limit = (Get-Date).AddDays(-$dayLimit)
  $Script:fileCount = f_fileMath -r 'cnt'

  # Test if there are files to be deleted
  if ($fileCount -gt 5){
    $strtTime = Get-Date #f_TimeStamp
    f_serviceControl -Service $Service -state 'stop'
    f_deleteFileFold
    f_serviceControl -Service $Service -state 'start'
    $stopTime = Get-Date # f_TimeStamp
    f_Output -Outputfile $Outputfile -strtTime $strtTime -stopTime $stopTime
    Write-Host ('Job Completed!  View Log: {0}\{1}' -f $workingLocation, $Logfile) -ForegroundColor White -BackgroundColor DarkGreen

  }
}
else{
  Write-Host '*** Re-run as an administrator ******' -ForegroundColor Black -BackgroundColor Yellow
}