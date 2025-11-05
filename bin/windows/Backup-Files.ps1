<#
.SYNOPSIS
    Automated file backup with compression and rotation
.DESCRIPTION
    Creates compressed backups of directories with automatic rotation
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    1.0
#>

#Requires -RunAsAdministrator

# Configuration
$BackupSource = "C:\Users"
$BackupDest = "C:\Backups"
$RetentionDays = 7
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
# Function: Get-FolderSize
################################################################################
function Get-FolderSize {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $size = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size / 1MB, 2)
    }
    return 0
}

################################################################################
# Function: Format-FileSize
################################################################################
function Format-FileSize {
    param([double]$SizeMB)
    
    if ($SizeMB -ge 1024) {
        return "{0:N2} GB" -f ($SizeMB / 1024)
    }
    return "{0:N2} MB" -f $SizeMB
}

################################################################################
# Function: Test-DiskSpace
################################################################################
function Test-DiskSpace {
    param([string]$Path)
    
    Write-Host "`n[INFO] Checking disk space..." -ForegroundColor Cyan
    
    $Drive = (Get-Item $Path).PSDrive
    $FreeSpace = [math]::Round($Drive.Free / 1GB, 2)
    $UsedSpace = [math]::Round($Drive.Used / 1GB, 2)
    
    Write-Host "[SUCCESS] Available: $FreeSpace GB" -ForegroundColor Green
    Write-Host "[SUCCESS] Used: $UsedSpace GB" -ForegroundColor Green
    
    return $FreeSpace -gt 1
}

################################################################################
# Function: New-CompressedBackup
################################################################################
function New-CompressedBackup {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Creating Backup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Validate source
    if (-not (Test-Path $Source)) {
        Write-Host "[ERROR] Source path does not exist: $Source" -ForegroundColor Red
        return $false
    }
    
    # Create destination if needed
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Write-Host "[SUCCESS] Created backup directory: $Destination" -ForegroundColor Green
    }
    
    # Generate backup filename
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $SourceName = Split-Path $Source -Leaf
    $BackupName = "backup_${SourceName}_${Timestamp}.zip"
    $BackupPath = Join-Path $Destination $BackupName
    
    Write-Host "`n[INFO] Creating backup: $BackupName" -ForegroundColor Cyan
    
    # Get source size
    $SourceSize = Get-FolderSize -Path $Source
    Write-Host "[INFO] Source size: $(Format-FileSize $SourceSize)" -ForegroundColor Cyan
    
    try {
        # Create compressed backup
        Write-Host "[INFO] Compressing files (this may take a while)..." -ForegroundColor Yellow
        
        Compress-Archive -Path $Source -DestinationPath $BackupPath -CompressionLevel Optimal -Force
        
        Write-Host "[SUCCESS] Backup created successfully" -ForegroundColor Green
        
        # Get backup size
        $BackupSize = (Get-Item $BackupPath).Length / 1MB
        $CompressionRatio = [math]::Round((1 - ($BackupSize / $SourceSize)) * 100, 1)
        
        Write-Host "[SUCCESS] Backup size: $(Format-FileSize $BackupSize)" -ForegroundColor Green
        Write-Host "[SUCCESS] Compression ratio: $CompressionRatio%" -ForegroundColor Green
        Write-Host "[SUCCESS] Saved to: $BackupPath" -ForegroundColor Green
        
        Write-AuditLog -Action "BACKUP_CREATE" -Result "SUCCESS" -Details "source=$Source size=$(Format-FileSize $BackupSize) file=$BackupName compression=$CompressionRatio%"
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to create backup: $_" -ForegroundColor Red
        Write-AuditLog -Action "BACKUP_CREATE" -Result "FAILURE" -Details "source=$Source error=$($_.Exception.Message)"
        return $false
    }
}

################################################################################
# Function: Remove-OldBackups
################################################################################
function Remove-OldBackups {
    param(
        [string]$Path,
        [int]$RetentionDays
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Rotating Old Backups" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[INFO] Retention policy: $RetentionDays days" -ForegroundColor Cyan
    
    if (-not (Test-Path $Path)) {
        Write-Host "[INFO] No backups directory found" -ForegroundColor Yellow
        return
    }
    
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $OldBackups = Get-ChildItem -Path $Path -Filter "backup_*.zip" | 
                  Where-Object { $_.LastWriteTime -lt $CutoffDate }
    
    if ($OldBackups.Count -eq 0) {
        Write-Host "[INFO] No old backups to delete" -ForegroundColor Yellow
        return
    }
    
    $DeletedCount = 0
    foreach ($Backup in $OldBackups) {
        try {
            $Size = Format-FileSize ($Backup.Length / 1MB)
            Remove-Item $Backup.FullName -Force
            Write-Host "[SUCCESS] Deleted: $($Backup.Name) ($Size)" -ForegroundColor Green
            $DeletedCount++
        }
        catch {
            Write-Host "[ERROR] Failed to delete: $($Backup.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host "[SUCCESS] Deleted $DeletedCount old backup(s)" -ForegroundColor Green
    Write-AuditLog -Action "BACKUP_ROTATE" -Result "SUCCESS" -Details "deleted=$DeletedCount retention=${RetentionDays}d"
}

################################################################################
# Function: Get-BackupList
################################################################################
function Get-BackupList {
    param([string]$Path)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Current Backups" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $Path)) {
        Write-Host "[INFO] No backups directory found" -ForegroundColor Yellow
        return
    }
    
    $Backups = Get-ChildItem -Path $Path -Filter "backup_*.zip" | Sort-Object LastWriteTime -Descending
    
    if ($Backups.Count -eq 0) {
        Write-Host "[INFO] No backups found" -ForegroundColor Yellow
        return
    }
    
    foreach ($Backup in $Backups) {
        $Size = Format-FileSize ($Backup.Length / 1MB)
        $Date = $Backup.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        Write-Host "  $($Backup.Name) - $Size - $Date" -ForegroundColor White
    }
}

################################################################################
# Main Script
################################################################################

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " Windows Backup Script v1.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Running with Administrator privileges" -ForegroundColor Green

# Configuration summary
Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Source: $BackupSource" -ForegroundColor White
Write-Host "  Destination: $BackupDest" -ForegroundColor White
Write-Host "  Retention: $RetentionDays days" -ForegroundColor White

# Check disk space
if (-not (Test-DiskSpace -Path $BackupDest)) {
    Write-Host "[WARNING] Low disk space!" -ForegroundColor Yellow
}

# Create backup
if (New-CompressedBackup -Source $BackupSource -Destination $BackupDest) {
    # Rotate old backups
    Remove-OldBackups -Path $BackupDest -RetentionDays $RetentionDays
    
    # Show current backups
    Get-BackupList -Path $BackupDest
    
    Write-Host "`n[SUCCESS] Backup completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Backup failed!" -ForegroundColor Red
    exit 1
}
