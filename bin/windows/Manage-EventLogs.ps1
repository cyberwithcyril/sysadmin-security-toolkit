<#
.SYNOPSIS
    Windows Event Log management and archival
.DESCRIPTION
    Archive, clear, and analyze Windows Event Logs with retention policies
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    1.0
#>

#Requires -RunAsAdministrator

# Configuration
$ArchivePath = "C:\Logs\EventLogArchives"
$RetentionDays = 30
$MaxLogSizeMB = 100
$AuditLog = "C:\Logs\SysAdminToolkit\audit.log"
$LogDir = "C:\Logs\SysAdminToolkit"

################################################################################
# Function: Write-AuditLog
################################################################################
function Write-AuditLog {
    param(
        [string]$Action,
        [string]$Result,
        [string]$Details
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] ACTION:$Action RESULT:$Result DETAILS:$Details"
    
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    Add-Content -Path $AuditLog -Value $LogEntry
}

################################################################################
# Function: Test-Administrator
################################################################################
function Test-Administrator {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

################################################################################
# Function: Get-EventLogInfo
################################################################################
function Get-EventLogInfo {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Event Log Status" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $Logs = @('System', 'Application', 'Security')
    
    foreach ($LogName in $Logs) {
        try {
            $Log = Get-WinEvent -ListLog $LogName -ErrorAction Stop
            
            $RecordCount = $Log.RecordCount
            $SizeMB = [math]::Round($Log.FileSize / 1MB, 2)
            $MaxSizeMB = [math]::Round($Log.MaximumSizeInBytes / 1MB, 2)
            $PercentFull = [math]::Round(($SizeMB / $MaxSizeMB) * 100, 1)
            
            Write-Host "`n$LogName Log:" -ForegroundColor Yellow
            Write-Host "  Records: $RecordCount" -ForegroundColor White
            Write-Host "  Size: $SizeMB MB / $MaxSizeMB MB ($PercentFull% full)" -ForegroundColor White
            Write-Host "  Path: $($Log.LogFilePath)" -ForegroundColor Gray
            
            if ($SizeMB -gt $MaxLogSizeMB) {
                Write-Host "  [WARNING] Log exceeds size limit!" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "`n$LogName Log: [ERROR] Unable to access" -ForegroundColor Red
        }
    }
}

################################################################################
# Function: Export-EventLogArchive
################################################################################
function Export-EventLogArchive {
    param(
        [string]$LogName,
        [string]$ArchivePath
    )
    
    Write-Host "`n[INFO] Archiving $LogName event log..." -ForegroundColor Cyan
    
    # Create archive directory
    if (-not (Test-Path $ArchivePath)) {
        New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
    }
    
    # Generate archive filename
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ArchiveFile = Join-Path $ArchivePath "${LogName}_${Timestamp}.evtx"
    
    try {
        # Export log
        wevtutil.exe epl $LogName $ArchiveFile
        
        if (Test-Path $ArchiveFile) {
            $SizeMB = [math]::Round((Get-Item $ArchiveFile).Length / 1MB, 2)
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

################################################################################
# Function: Clear-EventLogSafe
################################################################################
function Clear-EventLogSafe {
    param(
        [string]$LogName,
        [switch]$ArchiveFirst
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Clearing Event Log: $LogName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Archive first if requested
    if ($ArchiveFirst) {
        Write-Host "[INFO] Archiving before clearing..." -ForegroundColor Yellow
        if (-not (Export-EventLogArchive -LogName $LogName -ArchivePath $ArchivePath)) {
            Write-Host "[ERROR] Archive failed - aborting clear operation" -ForegroundColor Red
            return $false
        }
    }
    
    try {
        # Get record count before clearing
        $RecordsBefore = (Get-WinEvent -ListLog $LogName).RecordCount
        
        # Clear the log
        wevtutil.exe cl $LogName
        
        $RecordsAfter = (Get-WinEvent -ListLog $LogName).RecordCount
        
        Write-Host "[SUCCESS] Log cleared" -ForegroundColor Green
        Write-Host "[INFO] Records removed: $RecordsBefore" -ForegroundColor Cyan
        Write-Host "[INFO] Current records: $RecordsAfter" -ForegroundColor Cyan
        
        Write-AuditLog -Action "EVENTLOG_CLEAR" -Result "SUCCESS" -Details "log=$LogName records_removed=$RecordsBefore archived=$ArchiveFirst"
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to clear log: $_" -ForegroundColor Red
        Write-AuditLog -Action "EVENTLOG_CLEAR" -Result "FAILURE" -Details "log=$LogName error=$($_.Exception.Message)"
        return $false
    }
}

################################################################################
# Function: Get-EventLogSummary
################################################################################
function Get-EventLogSummary {
    param(
        [string]$LogName,
        [int]$Hours = 24
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $LogName Log Summary (Last $Hours hours)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $StartTime = (Get-Date).AddHours(-$Hours)
    
    try {
        $Events = Get-WinEvent -FilterHashtable @{
            LogName = $LogName
            StartTime = $StartTime
        } -ErrorAction Stop
        
        # Count by level
        $ErrorCount = ($Events | Where-Object {$_.Level -eq 2}).Count
        $WarningCount = ($Events | Where-Object {$_.Level -eq 3}).Count
        $InfoCount = ($Events | Where-Object {$_.Level -eq 4}).Count
        
        Write-Host "`nTotal Events: $($Events.Count)" -ForegroundColor White
        Write-Host "  Errors: $ErrorCount" -ForegroundColor Red
        Write-Host "  Warnings: $WarningCount" -ForegroundColor Yellow
        Write-Host "  Information: $InfoCount" -ForegroundColor Green
        
        # Show top 5 error sources
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

################################################################################
# Function: Remove-OldArchives
################################################################################
function Remove-OldArchives {
    param(
        [string]$ArchivePath,
        [int]$RetentionDays
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Removing Old Archives" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[INFO] Retention: $RetentionDays days" -ForegroundColor Cyan
    
    if (-not (Test-Path $ArchivePath)) {
        Write-Host "[INFO] No archives directory found" -ForegroundColor Yellow
        return
    }
    
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $OldArchives = Get-ChildItem -Path $ArchivePath -Filter "*.evtx" | 
                   Where-Object { $_.LastWriteTime -lt $CutoffDate }
    
    if ($OldArchives.Count -eq 0) {
        Write-Host "[INFO] No old archives to delete" -ForegroundColor Yellow
        return
    }
    
    $DeletedCount = 0
    $TotalSizeMB = 0
    
    foreach ($Archive in $OldArchives) {
        try {
            $SizeMB = [math]::Round($Archive.Length / 1MB, 2)
            $TotalSizeMB += $SizeMB
            Remove-Item $Archive.FullName -Force
            Write-Host "[SUCCESS] Deleted: $($Archive.Name) ($SizeMB MB)" -ForegroundColor Green
            $DeletedCount++
        }
        catch {
            Write-Host "[ERROR] Failed to delete: $($Archive.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n[SUCCESS] Deleted $DeletedCount archive(s), freed $TotalSizeMB MB" -ForegroundColor Green
    Write-AuditLog -Action "EVENTLOG_CLEANUP" -Result "SUCCESS" -Details "deleted=$DeletedCount size_freed=${TotalSizeMB}MB retention=${RetentionDays}d"
}

################################################################################
# Main Script
################################################################################

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " Windows Event Log Management v1.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Running with Administrator privileges" -ForegroundColor Green

# Configuration
Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Archive Path: $ArchivePath" -ForegroundColor White
Write-Host "  Retention: $RetentionDays days" -ForegroundColor White
Write-Host "  Max Log Size: $MaxLogSizeMB MB" -ForegroundColor White

# Show current status
Get-EventLogInfo

# Show recent summaries
Get-EventLogSummary -LogName "System" -Hours 24
Get-EventLogSummary -LogName "Application" -Hours 24

# Check for old archives
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
