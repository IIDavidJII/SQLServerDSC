 #Degrees of paraellism 
$iParallelism = (Get-CimInstance -Class 'CIM_Processor' | Measure-Object -Property numberofcores -Sum).Sum / 2

Switch ($iParallelism)
{
  {$iParallelism -ge 8} {$iParallelism = 8}
  {$iParallelism -lt 8} {$iParallelism}
}
 
 #Memmory to be allocated see https://sqlmax.chuvash.eu/
  $iTotalMemory = (Get-CimInstance -Class 'cim_physicalmemory' | Measure-Object -Property capacity -Sum).sum
  $iTotalMemoryGB = ($iTotalMemory * [math]::Pow(2,-30))


 Switch ($iMinMemory)
{
 
  {$iTotalMemoryGB -ge 16} {$iMinMemory = 8 * 1024}
  {$iTotalMemoryGB -lt 16} {$iMinMemory = 4 * 1024}
}

Switch ($osReserved)
{
  {$iTotalMemorygb -ge 20}{$iTotalMemory *.125}
  {$iTotalMemorygb -lt 20 -and $iTotalMemory -gt 15} {15 * [math]::Pow(2,-30)}
  {$iTotalMemorygb -le 15} {$iTotalMemory * .2}
}

$iCpuCores = (Get-CimInstance -Class 'CIM_Processor' | Measure-Object -Property numberofcores -Sum).Sum
$numSQLThreads = IF ($iCpuCores -gt 4) {256 + (($iCpuCores  -4) * 8)} ELSE {256}
$threadStackSizeX64 = 4194304
$osReserved = IF ($iTotalMemorygb -lt 20) {($iTotalMemory * .2)} ELSE {$iTotalMemory * .125}

$iMaxMemory = (($iTotalMemory  - ($numSQLThreads * $threadStackSizeX64)  - ([math]::Pow(2,30) * 1 * ($iCpuCores /4)) - $osReserved) * [math]::Pow(2,-20)) 

#SQLSetup Variables
$SQLTempdbFileCount = IF($iCpuCores -gt 8) {8} ELSE {$iCpuCores}
$SQLTempDBFileSize = (((Get-Volume -DriveLetter 'T').Size * .9 * [math]::Pow(2,-20)) / $SQLTempdbFileCount)

Configuration SQLServerDsc {

  Import-DscResource -ModuleName SqlServerDsc

  Node localhost
  {
    WindowsFeature 'NetFramework45'
    {
      Name = 'Net-Framework-45-Core'
      Ensure = 'Present'

    }

    File SQLData_folder
    {
      Ensure = "Present"
      Type = "Directory"
      DestinationPath = "D:\Data"
    }

    File SQLLog_folder
    {
      Ensure = "Present"
      Type = "Directory"
      DestinationPath = "L:\Log"
    }

    File SQLBackup_folder
    {
      Ensure = "Present"
      Type = "Directory"
      DestinationPath = "B:\Backup"
    }

    SqlSetup 'InstallDefaultInstance'
    {
      InstanceName = 'MSSQLServer'
      Features = 'SQLEngine'
      SourcePath = 'D:\'
      SQLSysAdminAccounts = @('Administrators')
      InstallSQLDataDir = 'D:\Data'
      SQLUserDBDir = 'D:\Data'
      SQLUserDBLogDir = 'L:\Log'     
      SQLTempDBDir = 'T:\'
      SQLTempDBLOGDir = 'L:\'
      SQLBackupDir = 'B:\Backup'
      SQLTempdbFileCount = $SQLTempdbFileCount
      SQLTempdbFileSize = $SQLTempDBFileSize      
      DependsOn = '[WindowsFeature]NetFramework45'
    }

    SQLDatabaseDefaultLocation Set_DataFile_Location {

      ServerName = $env:COMPUTERNAME
      InstanceName = 'MSSQLServer'
      Type = 'Data'
      Path = 'D:\Data'
    }

    SQLDatabaseDefaultLocation Set_LogFile_Location {
      ServerName = $env:COMPUTERNAME
      InstanceName = 'MSSQLServer'
      Type = 'Log'
      Path = 'L:\Log'

    }

    SQLDatabaseDefaultLocation Set_Backup_Location {
      ServerName = $env:COMPUTERNAME
      InstanceName = 'MSSQLServer'
      Type = 'Backup'
      Path = 'B:\Backup'

    }

    SQLServerMemory Set_SQLServerMemory {
      ServerName = $env:COMPUTERNAME
      InstanceName = 'MSSQLServer'
      MinMemory = $iMinMemory
      MaxMemory = $iMinMemory
      
    }

    SQLServerMaxDop Set_SQLServerParallelism {
      Servername = $env:COMPUTERNAME
      InstanceName = 'MSSQLServer'
      Ensure = 'Present'
      MaxDop = $iParallelism
    }

  }

}

SQLServerDsc -OutputPath C:\SQLinstall

Start-DscConfiguration -Path c:\sqlInstall -Wait -Force -Verbose #Degrees of paraellism 
