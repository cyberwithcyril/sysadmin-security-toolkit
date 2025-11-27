<#*******************************************************************************
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
*********************************************************************************#>

#Requires -RunAsAdministrator

# Configuration
$BackupSource = "C:\Users\Administrator\Documents" #What to Backup
$BackupDest = "C:\Backups" #Where to Save Backups
$RetentionDays = 7 #How Long to Keep Backups
$AuditLog = "C:\Logs\SysAdminToolkit\audit.log" #Path for Log File
$LogDir = "C:\Logs\SysAdminToolkit" #Log Directory

#******************************************************************************
# Function: Write-AuditLog
#******************************************************************************
#Functiont takes three parameters, gets current timestap and formats log entry with timestamp
#and info, appends log entry to audit file
function Write-AuditLog {
    param(
        [string]$Action,
        [string]$Result,
        [string]$Details
    )

#Get Timestamp    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#Log Format
    $LogEntry = "[$Timestamp] ACTION:$Action RESULT:$Result DETAILS:$Details"

#Checks if path exists - if not creates new directory    
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
 #Adds the Log Entry to Audit Log   
    Add-Content -Path $AuditLog -Value $LogEntry
}

#******************************************************************************
# Function: Test-Administrator
#******************************************************************************
#Function Checks if script is running as Administrative

function Test-Administrator {
#Current User - Checks Current User using Windows Identity .NET class
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
#Creates security pricinpal object
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
#Checks if user is in Administrator role - returns true or false
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

##******************************************************************************
# Function: Get-FolderSize
#*******************************************************************************
#Function Checks if folder path exists, Gets all files and sums up all file size, 
#the converts bytes to MB
function Get-FolderSize {

#Takes Path Parameter
    param([string]$Path)
#Calculates Total Size - Gets all files and folders in the path, includes subdirectories
#-Property Length = file size and sums it all up   
    if (Test-Path $Path) {
        $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
        
        if ($files) {
            $size = ($files | Measure-Object -Property Length -Sum).Sum
            if ($size) {
                return [math]::Round($size / 1MB, 2)
            }
        }
    }
    return 0
}

#*******************************************************************************
# Function: Format-FileSize
#*******************************************************************************
#Format File size - if >1024 - show as GB; if < 1024 MB show as MB
function Format-FileSize {
    param([double]$SizeMB)
    
    if ($SizeMB -ge 1024) {
        # Show as GB for files > 1024 MB
        return "{0:N2} GB" -f ($SizeMB / 1024)
    }
    elseif ($SizeMB -ge 1) {
        # Show as MB for files >= 1 MB
        return "{0:N2} MB" -f $SizeMB
    }
    else {
        # Show as KB for files < 1 MB
        return "{0:N2} KB" -f ($SizeMB * 1024)
    }
}

#******************************************************************************
# Function: Test-DiskSpace
#******************************************************************************
#Function gets drive infortion, calculates free/used space in GP, returns drive 
#usage display
function Test-DiskSpace {
    param([string]$Path)
    
    Write-Host "`n[INFO] Checking disk space..." -ForegroundColor Cyan
    
    #.PSDrive - gets drive properties
    $Drive = (Get-Item $Path).PSDrive
    $FreeSpace = [math]::Round($Drive.Free / 1GB, 2)
    $UsedSpace = [math]::Round($Drive.Used / 1GB, 2)
    
    Write-Host "[SUCCESS] Available: $FreeSpace GB" -ForegroundColor Green
    Write-Host "[SUCCESS] Used: $UsedSpace GB" -ForegroundColor Green
    
#Only Returns True if Free Space is greater than 1 GB
    return $FreeSpace -gt 1
}

#******************************************************************************
# Function: New-CompressedBackup
#******************************************************************************
#Creates Backup, Calculates Backup Size, Calculates Space Saved - Compression
function New-CompressedBackup {
    param(
        [string]$Source, #what to backup
        [string]$Destination #where to save the backup
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Creating Backup" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
#Validate source
    if (-not (Test-Path $Source)) {
        Write-Host "[ERROR] Source path does not exist: $Source" -ForegroundColor Red
        return $false
    }
    
#Create destination if Destination Path does not exist
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Write-Host "[SUCCESS] Created backup directory: $Destination" -ForegroundColor Green
    }
    
#Generate backup filename
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
#Gets the Last Part of a Path
    $SourceName = Split-Path $Source -Leaf
#Backup filename format
    $BackupName = "backup_${SourceName}_${Timestamp}.zip"
#Combines Path to Save the File with Formatted File
    $BackupPath = Join-Path $Destination $BackupName
    
    Write-Host "`n[INFO] Creating backup: $BackupName" -ForegroundColor Cyan
    
#Get source size

    $SourceSize = Get-FolderSize -Path $Source
    Write-Host "[INFO] Source size: $(Format-FileSize $SourceSize)" -ForegroundColor Cyan
    
    try {
       
        Write-Host "[INFO] Compressing files (this may take a while)..." -ForegroundColor Yellow
#Creates Backup - Compress-Archive - PS Command to Create zip files 
        Compress-Archive -Path "$Source\*" -DestinationPath $BackupPath -CompressionLevel Optimal -Force

       
        Write-Host "[SUCCESS] Backup created successfully" -ForegroundColor Green
        
     $fileCount = (Get-ChildItem -Path $Source -Recurse -File -ErrorAction SilentlyContinue).Count
  
      Write-Host "[SUCCESS] Files backed up: $fileCount" -ForegroundColor Green       


if (-not (Test-Path $BackupPath)) {
    Write-Host "[WARNING] No files to backup - backup file not created" -ForegroundColor Yellow
    Write-AuditLog -Action "BACKUP_CREATE" -Result "FAILURE" -Details "source=$Source error=empty_source"
    return $false
}
#Get backup size
#Get info about the zip file in bytes
        $BackupSize = (Get-Item $BackupPath).Length / 1MB
#Calculate space saved
        if ($SourceSize -gt 0) {
            $CompressionRatio = [math]::Round((1 - ($BackupSize / $SourceSize)) * 100, 1)
        } else {
            $CompressionRatio = 0
        }

        #Success Logs
        if ($SourceSize -eq 0) {
            Write-Host "[WARNING] Source folder is empty (0 files backed up)" -ForegroundColor Yellow
            Write-Host "[SUCCESS] Empty backup created: $(Format-FileSize $BackupSize)" -ForegroundColor Green
            Write-Host "[SUCCESS] Saved to: $BackupPath" -ForegroundColor Green
        } else {
            Write-Host "[SUCCESS] Backup size: $(Format-FileSize $BackupSize)" -ForegroundColor Green
            Write-Host "[SUCCESS] Compression ratio: $CompressionRatio%" -ForegroundColor Green
            Write-Host "[SUCCESS] Saved to: $BackupPath" -ForegroundColor Green
        }

#Creates Log Entry      
        Write-AuditLog -Action "BACKUP_CREATE" -Result "SUCCESS" -Details "source=$Source size=$(Format-FileSize $BackupSize) file=$BackupName compression=$CompressionRatio%"
        
        return $true
    }
#Catches Backup Failure/Error
    catch {
        Write-Host "[ERROR] Failed to create backup: $_" -ForegroundColor Red
        Write-AuditLog -Action "BACKUP_CREATE" -Result "FAILURE" -Details "source=$Source error=$($_.Exception.Message)"
        return $false
    }
}

#******************************************************************************
# Function: Remove-OldBackups
#******************************************************************************
#Function Delete Backup Files Older than Retention Period

function Remove-OldBackups {
    param(
        [string]$Path, #Backup folder
        [int]$RetentionDays
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Rotating Old Backups" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[INFO] Retention policy: $RetentionDays days" -ForegroundColor Cyan

#Check if Backup Folder Exists
    if (-not (Test-Path $Path)) {
        Write-Host "[INFO] No backups directory found" -ForegroundColor Yellow
        return
    }
#Creates Cut Off Date from Current Date - Retention Days [7]
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)

#Finds Old Backup - Checks Current File, Last Modified and Compares it with the Cut Off Date
    $OldBackups = Get-ChildItem -Path $Path -Filter "backup_*.zip" | 
                  Where-Object { $_.LastWriteTime -lt $CutoffDate }

#Checks the OldBackups Total in the List
    if ($OldBackups.Count -eq 0) {
        Write-Host "[INFO] No old backups to delete" -ForegroundColor Yellow
        return
    }

#Deleted Files Counter    
    $DeletedCount = 0

#Deletes Each Old Backup by Looping through each old Backup
    foreach ($Backup in $OldBackups) {
        try {
            $Size = Format-FileSize ($Backup.Length / 1MB)
            Remove-Item $Backup.FullName -Force
            Write-Host "[SUCCESS] Deleted: $($Backup.Name) ($Size)" -ForegroundColor Green
            $DeletedCount++
        }
#If Deletion Fails
        catch {
            Write-Host "[ERROR] Failed to delete: $($Backup.Name)" -ForegroundColor Red
        }
    }

#Shows Total Deleted & Logs to Audit File 
    Write-Host "[SUCCESS] Deleted $DeletedCount old backup(s)" -ForegroundColor Green
    Write-AuditLog -Action "BACKUP_ROTATE" -Result "SUCCESS" -Details "deleted=$DeletedCount retention=${RetentionDays}d"
}

#******************************************************************************
# Function: Get-BackupList
#******************************************************************************
#Displays all Current Backups

function Get-BackupList {
    param([string]$Path)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Current Backups" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
#Checks if Backup Directory Exists
    if (-not (Test-Path $Path)) {
        Write-Host "[INFO] No backups directory found" -ForegroundColor Yellow
        return
    }
#Retrieves all Backups - Soreted    
    $Backups = Get-ChildItem -Path $Path -Filter "backup_*.zip" | Sort-Object LastWriteTime -Descending

#If no Backups Found  
    if ($Backups.Count -eq 0) {
        Write-Host "[INFO] No backups found" -ForegroundColor Yellow
        return
    }
#Displays Each Backup in the Fomat - Name, Size, & Date   
    foreach ($Backup in $Backups) {
        $Size = Format-FileSize ($Backup.Length / 1MB)
        $Date = $Backup.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        Write-Host "  $($Backup.Name) - $Size - $Date" -ForegroundColor White
    }
}

#*******************************************************************************
# Main Script - Interactive Menu
#*******************************************************************************

# Check administrator rights
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# Main menu loop
while ($true) {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host " Windows Backup Script v1.0" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Source: $BackupSource" -ForegroundColor White
    Write-Host "  Destination: $BackupDest" -ForegroundColor White
    Write-Host "  Retention: $RetentionDays days" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Create backup now" -ForegroundColor Yellow
    Write-Host "2. List current backups" -ForegroundColor Yellow
    Write-Host "3. Check disk space" -ForegroundColor Yellow
    Write-Host "4. Remove old backups" -ForegroundColor Yellow
    Write-Host "5. Custom backup (choose source)" -ForegroundColor Yellow
    Write-Host "6. Full backup cycle (backup + rotate)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "0. Exit to main menu" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            #Create backup now
            Clear-Host
            Write-Host "`n[INFO] Starting backup..." -ForegroundColor Cyan
            
            if (Test-DiskSpace -Path $BackupDest) {
                if (New-CompressedBackup -Source $BackupSource -Destination $BackupDest) {
                    Write-Host "`n[SUCCESS] Backup completed!" -ForegroundColor Green
                } else {
                    Write-Host "`n[ERROR] Backup failed!" -ForegroundColor Red
                }
            } else {
                Write-Host "`n[WARNING] Insufficient disk space!" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "2" {
            #List current backups
            Clear-Host
            Get-BackupList -Path $BackupDest
            Read-Host "`nPress Enter to continue"
        }
        "3" {
            #Check disk space
            Clear-Host
            Test-DiskSpace -Path $BackupDest
            Read-Host "`nPress Enter to continue"
        }
        "4" {
            #Remove old backups
            Clear-Host
            Write-Host "`n[INFO] Checking for old backups..." -ForegroundColor Cyan
            Remove-OldBackups -Path $BackupDest -RetentionDays $RetentionDays
            Read-Host "`nPress Enter to continue"
        }
        "5" {
            #Custom backup
            Clear-Host
            Write-Host "`n[INFO] Custom Backup" -ForegroundColor Cyan
            $customSource = Read-Host "`nEnter source path (e.g., C:\Users\Documents)"
            
            if (Test-Path $customSource) {
                Write-Host "`n[INFO] Source: $customSource" -ForegroundColor Cyan
                $confirm = Read-Host "Proceed with backup? (yes/no)"
                
                if ($confirm -eq "yes") {
                    if (Test-DiskSpace -Path $BackupDest) {
                        if (New-CompressedBackup -Source $customSource -Destination $BackupDest) {
                            Write-Host "`n[SUCCESS] Custom backup completed!" -ForegroundColor Green
                        } else {
                            Write-Host "`n[ERROR] Backup failed!" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "`n[WARNING] Insufficient disk space!" -ForegroundColor Red
                    }
                } else {
                    Write-Host "[INFO] Backup cancelled" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[ERROR] Source path does not exist!" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "6" {
            #Full backup cycle
            Clear-Host
            Write-Host "`n=========================================" -ForegroundColor Cyan
            Write-Host " Full Backup Cycle" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            
            #Check disk space
            if (Test-DiskSpace -Path $BackupDest) {
                #Create backup
                if (New-CompressedBackup -Source $BackupSource -Destination $BackupDest) {
                    #Rotate old backups
                    Remove-OldBackups -Path $BackupDest -RetentionDays $RetentionDays
                    
                    #Show current backups
                    Get-BackupList -Path $BackupDest
                    
                    Write-Host "`n[SUCCESS] Full backup cycle completed!" -ForegroundColor Green
                } else {
                    Write-Host "`n[ERROR] Backup failed!" -ForegroundColor Red
                }
            } else {
                Write-Host "`n[WARNING] Insufficient disk space - backup cancelled!" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "0" {
            Write-Host "`nReturning to main menu..." -ForegroundColor Green
            exit 0
        }
        default {
            Write-Host "`n[ERROR] Invalid option" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}