<#*********************************************************************************
.SYNOPSIS
    Windows Event Log management and archival
.DESCRIPTION
    Manages Windows Event Logs - Archives, Clears, & Analyzes
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    1.0
**************************************************************************************#>

#Requires -RunAsAdministrator

# Configuration
$ArchivePath = "C:\Logs\EventLogArchives" 
$RetentionDays = 30
$MaxLogSizeMB = 100 #Alert Threshold for max log size
$AuditLog = "C:\Logs\SysAdminToolkit\audit.log"
$LogDir = "C:\Logs\SysAdminToolkit"

#*******************************************************************************
# Function: Write-AuditLog
#*******************************************************************************
#Takes Action, Result, & Detail as Input, - Creates Log and Appends to Audit Log File
function Write-AuditLog {
    param(
        [string]$Action,
        [string]$Result,
        [string]$Details
    )

#Creates Timestamp & Log Entry Format 
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] ACTION:$Action RESULT:$Result DETAILS:$Details"

#Checks if Log Directory Exists - if not creates new    
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

#Logs Event   
    Add-Content -Path $AuditLog -Value $LogEntry
}

#******************************************************************************
# Function: Test-Administrator
#******************************************************************************]
#Gets current Windows user & Checks if user is in Administrator group

function Test-Administrator {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#******************************************************************************
# Function: Get-EventLogInfo
#*******************************************************************************
#Displays status of Windows Event Logs - System, Application, Security

function Get-EventLogInfo {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Event Log Status" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
#Checks Logs in System, Application, & Security
    $Logs = @('System', 'Application', 'Security')

#Gets infor about each log, total logs, size, percent full   
    foreach ($LogName in $Logs) {
        try {
            $Log = Get-WinEvent -ListLog $LogName -ErrorAction Stop
            
            $RecordCount = $Log.RecordCount
            $SizeMB = [math]::Round($Log.FileSize / 1MB, 2)
            $MaxSizeMB = [math]::Round($Log.MaximumSizeInBytes / 1MB, 2)
            $PercentFull = [math]::Round(($SizeMB / $MaxSizeMB) * 100, 1)

#Displays Log Information      
            Write-Host "`n$LogName Log:" -ForegroundColor Yellow
            Write-Host "  Records: $RecordCount" -ForegroundColor White
            Write-Host "  Size: $SizeMB MB / $MaxSizeMB MB ($PercentFull% full)" -ForegroundColor White
            Write-Host "  Path: $($Log.LogFilePath)" -ForegroundColor Gray

#If Log Size is greater than MaxSize           
            if ($SizeMB -gt $MaxLogSizeMB) {
                Write-Host "  [WARNING] Log exceeds size limit!" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "`n$LogName Log: [ERROR] Unable to access" -ForegroundColor Red
        }
    }
}

#*******************************************************************************
# Function: Export-EventLogArchive
#*******************************************************************************
#Creates a backup copy of a Windows event log
function Export-EventLogArchive {
    param(
        [string]$LogName,
        [string]$ArchivePath
    )
    
    Write-Host "`n[INFO] Archiving $LogName event log..." -ForegroundColor Cyan
    
#Create archive directory
    if (-not (Test-Path $ArchivePath)) {
        New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
    }
    
#Generate archive filename
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
#Builds File Name & Combines Path
    $ArchiveFile = Join-Path $ArchivePath "${LogName}_${Timestamp}.evtx"
    
    try {

#Export log
#wevtutil.exe - Windows Event Utility Program - epl - Export Log Command [save as]
#Reads all events from a log and writes them to a file

        wevtutil.exe epl $LogName $ArchiveFile

#Checks if Archive Created 
        if (Test-Path $ArchiveFile) {
#Gets Archive Size
            $SizeMB = [math]::Round((Get-Item $ArchiveFile).Length / 1MB, 2)
#Prints & Logs Action
            Write-Host "[SUCCESS] Archived to: $ArchiveFile ($SizeMB MB)" -ForegroundColor Green
            Write-AuditLog -Action "EVENTLOG_ARCHIVE" -Result "SUCCESS" -Details "log=$LogName size=${SizeMB}MB file=$(Split-Path $ArchiveFile -Leaf)"
            return $true
        }
        else {
            Write-Host "[ERROR] Archive file not created" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Failed to archive: $_" -ForegroundColor Red
        Write-AuditLog -Action "EVENTLOG_ARCHIVE" -Result "FAILURE" -Details "log=$LogName error=$($_.Exception.Message)"
        return $false
    }
}

#*******************************************************************************
# Function: Clear-EventLogSafe
#*******************************************************************************
#Safely Clears a Windows Event Log

function Clear-EventLogSafe {
    param(
        [string]$LogName,
        [switch]$ArchiveFirst
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Clearing Event Log: $LogName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
#Checks Archive Flag if user wants to Archive First
    if ($ArchiveFirst) {
        Write-Host "[INFO] Archiving before clearing..." -ForegroundColor Yellow

#Attempts to Archive
        if (-not (Export-EventLogArchive -LogName $LogName -ArchivePath $ArchivePath)) {
            Write-Host "[ERROR] Archive failed - aborting clear operation" -ForegroundColor Red
            return $false
        }
    }
    
    try {
#Gets Count of Records Before Deletion
        $RecordsBefore = (Get-WinEvent -ListLog $LogName).RecordCount
        
#Clears the log - using Windows Event Utility  & cl
        wevtutil.exe cl $LogName
        
#Gets Count of Records After Deletion
        $RecordsAfter = (Get-WinEvent -ListLog $LogName).RecordCount
        
#Display
        Write-Host "[SUCCESS] Log cleared" -ForegroundColor Green
        Write-Host "[INFO] Records removed: $RecordsBefore" -ForegroundColor Cyan
        Write-Host "[INFO] Current records: $RecordsAfter" -ForegroundColor Cyan
#Logs Action
        Write-AuditLog -Action "EVENTLOG_CLEAR" -Result "SUCCESS" -Details "log=$LogName records_removed=$RecordsBefore archived=$ArchiveFirst"
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to clear log: $_" -ForegroundColor Red
        Write-AuditLog -Action "EVENTLOG_CLEAR" -Result "FAILURE" -Details "log=$LogName error=$($_.Exception.Message)"
        return $false
    }
}

#*******************************************************************************
# Function: Get-EventLogSummary
#*******************************************************************************
#Analyzes Recent Events in a Log & Shows Statistics

function Get-EventLogSummary {
    param(
        [string]$LogName,
        [int]$Hours = 24 #How Far Back
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $LogName Log Summary (Last $Hours hours)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

#Calculates Start Time    
    $StartTime = (Get-Date).AddHours(-$Hours)
    
    try {
#Get Windows Events Filter the Criteria Based on Log Name & Start Time
        $Events = Get-WinEvent -FilterHashtable @{
            LogName = $LogName
            StartTime = $StartTime
        } -ErrorAction Stop
        
#Counts all Events that Have an Error [-eq 2 = Error]
        $ErrorCount = ($Events | Where-Object {$_.Level -eq 2}).Count
#Counts all Events that Have a Warning [-eq 3 = Warning]
        $WarningCount = ($Events | Where-Object {$_.Level -eq 3}).Count
#Counts all Events with Information [-eq 4 = Information]
        $InfoCount = ($Events | Where-Object {$_.Level -eq 4}).Count

#Displays Total Events, Count of Errors, Warnings, and Informational events        
        Write-Host "`nTotal Events: $($Events.Count)" -ForegroundColor White
        Write-Host "  Errors: $ErrorCount" -ForegroundColor Red
        Write-Host "  Warnings: $WarningCount" -ForegroundColor Yellow
        Write-Host "  Information: $InfoCount" -ForegroundColor Green
        
#Displays and Sorts Events - For Top Error Events
#Gets only error events - Groups error by source
        if ($ErrorCount -gt 0) {
            Write-Host "`nTop Error Sources:" -ForegroundColor Red
            $Events | Where-Object {$_.Level -eq 2} | 
                      Group-Object ProviderName | 
                      Sort-Object Count -Descending | 
                      Select-Object -First 5 | 
                      ForEach-Object {
                          Write-Host "  $($_.Name): $($_.Count) errors" -ForegroundColor White
                      }
        }
    }
    catch {
        Write-Host "[INFO] No events found in the specified time range" -ForegroundColor Yellow
    }
}

#******************************************************************************
# Function: Remove-OldArchives
#******************************************************************************
#Deletes Archived Event Logs Older Than Retention Period

function Remove-OldArchives {
    param(
        [string]$ArchivePath,
        [int]$RetentionDays
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Removing Old Archives" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[INFO] Retention: $RetentionDays days" -ForegroundColor Cyan

#Checks if Directory exists  
    if (-not (Test-Path $ArchivePath)) {
        Write-Host "[INFO] No archives directory found" -ForegroundColor Yellow
        return
    }

#Calculate Cut Off Date from Current Date and Retention Days
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
#Finds Old Archives - All Files Filtered for files modified before the cutoff
    $OldArchives = Get-ChildItem -Path $ArchivePath -Filter "*.evtx" | 
                   Where-Object { $_.LastWriteTime -lt $CutoffDate }
    
    if ($OldArchives.Count -eq 0) {
        Write-Host "[INFO] No old archives to delete" -ForegroundColor Yellow
        return
    }

#Deleted File Counter   
    $DeletedCount = 0
#Total Space Freed
    $TotalSizeMB = 0
    
    foreach ($Archive in $OldArchives) {
        try {

#Gets File Size in Bytes
            $SizeMB = [math]::Round($Archive.Length / 1MB, 2)
#Adds to Total
            $TotalSizeMB += $SizeMB
#Deletes File using the Full Path to File
            Remove-Item $Archive.FullName -Force
            Write-Host "[SUCCESS] Deleted: $($Archive.Name) ($SizeMB MB)" -ForegroundColor Green
            $DeletedCount++
        }
        catch {
            Write-Host "[ERROR] Failed to delete: $($Archive.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n[SUCCESS] Deleted $DeletedCount archive(s), freed $TotalSizeMB MB" -ForegroundColor Green
#Logs Action   
    Write-AuditLog -Action "EVENTLOG_CLEANUP" -Result "SUCCESS" -Details "deleted=$DeletedCount size_freed=${TotalSizeMB}MB retention=${RetentionDays}d"
}

################################################################################
# Main Script - Controller
################################################################################

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " Windows Event Log Management v1.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

#Check administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Running with Administrator privileges" -ForegroundColor Green

#Configuration
Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Archive Path: $ArchivePath" -ForegroundColor White
Write-Host "  Retention: $RetentionDays days" -ForegroundColor White
Write-Host "  Max Log Size: $MaxLogSizeMB MB" -ForegroundColor White

#Show current status
Get-EventLogInfo

#Show recent summaries
Get-EventLogSummary -LogName "System" -Hours 24
Get-EventLogSummary -LogName "Application" -Hours 24

#Check for old archives
Remove-OldArchives -ArchivePath $ArchivePath -RetentionDays $RetentionDays

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Available Commands" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Archive log:" -ForegroundColor Yellow
Write-Host "  Export-EventLogArchive -LogName 'System' -ArchivePath 'C:\Logs\EventLogArchives'" -ForegroundColor Gray
Write-Host "`nClear log (with archive):" -ForegroundColor Yellow
Write-Host "  Clear-EventLogSafe -LogName 'Application' -ArchiveFirst" -ForegroundColor Gray
Write-Host "`nGet summary:" -ForegroundColor Yellow
Write-Host "  Get-EventLogSummary -LogName 'System' -Hours 48" -ForegroundColor Gray
Write-Host ""
