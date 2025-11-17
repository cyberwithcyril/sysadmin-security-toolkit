<#*********************************************************************************
.SYNOPSIS
    Windows system resource monitoring with alerts
.DESCRIPTION
    Monitor CPU, Memory, Disk usage with configurable thresholds and alerting
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    1.0
************************************************************************************#>

#Requires -RunAsAdministrator

# Configuration - Thresholds - Can be Adjusted 
#Navigate to cd ~/sysadmin-security-toolkit/bin/linux
#command: sudo ./monitor_system.sh --cpu-threshold 80 --mem-threshold 60 --disk-threshold 80
$CPUThreshold = 80
$MemoryThreshold = 85
$DiskThreshold = 85
$AlertLog = "C:\Logs\SysAdminToolkit\alerts.log" #Critical Alerts Only
$LogDir = "C:\Logs\SysAdminToolkit"
$AuditLog = "C:\Logs\SysAdminToolkit\audit.log" #All Actions

#*******************************************************************************
# Function: Write-AuditLog
#*******************************************************************************
#Writes Logs to Audit File

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

#*******************************************************************************
# Function: Write-Alert
#*******************************************************************************
#Writes Critical Alerts to Alert Log

function Write-Alert {
    param(
        [string]$AlertType,
        [string]$Details
    )

#Gets Time Stamp and Formats The Entry with Time w Alert Type & Details of Event    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $AlertEntry = "[$Timestamp] ALERT:$AlertType $Details"

#Checks if Directory Exists - if not Creates new   
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

#Writes to Log  
    Add-Content -Path $AlertLog -Value $AlertEntry
    Write-AuditLog -Action "SYSTEM_ALERT" -Result "WARNING" -Details $Details
}

#*******************************************************************************
# Function: Test-Administrator
#*******************************************************************************
#Checks user is Administrator
function Test-Administrator {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#*******************************************************************************
# Function: Get-CPUUsage
#*******************************************************************************
#Measures CPU-Usafe and Alerts if Too High
function Get-CPUUsage {
    Write-Host "`n[INFO] Checking CPU usage..." -ForegroundColor Cyan
    
#Get CPU usage using PS[Get-Counter] Windows Performance Counters - Takes 2 Samples
#Takes Both Samples of CPU Usage and Gets the Average
    $CPUUsage = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2 | 
                 Select-Object -ExpandProperty CounterSamples | 
                 Measure-Object -Property CookedValue -Average).Average
    
    $CPUUsage = [math]::Round($CPUUsage, 1)
    
    Write-Host "  Current CPU usage: $CPUUsage%" -ForegroundColor White

#Checks & Compares to the Set CPU Threshold 
#If Current CPU Usage is greater than CPU Threshold - 'CPU High'   
    if ($CPUUsage -ge $CPUThreshold) {
       
#Sends Warning to User - Logs Action
        Write-Host "[WARNING] CPU usage above threshold ($CPUThreshold%)" -ForegroundColor Red
        Write-Alert -AlertType "CPU_HIGH" -Details "usage=${CPUUsage}% threshold=${CPUThreshold}%"
        return $false
    } else {
        Write-Host "[SUCCESS] CPU usage normal" -ForegroundColor Green
        return $true
    }
}

#***********************************************************************************
# Function: Get-MemoryUsage
#***********************************************************************************
#Measures RAM usage and alerts if too high

function Get-MemoryUsage {
    Write-Host "`n[INFO] Checking memory usage..." -ForegroundColor Cyan

#Uses [Get-CimInstance] access Query WMI -    
    $OS = Get-CimInstance Win32_OperatingSystem
#Gets Total Memory in KB of OS
    $TotalMemory = $OS.TotalVisibleMemorySize
#Gets Free Memory in KB of OS
    $FreeMemory = $OS.FreePhysicalMemory
#Calcualtes Used Memory and Converts to Percent
    $UsedMemory = $TotalMemory - $FreeMemory
    $MemoryPercent = [math]::Round(($UsedMemory / $TotalMemory) * 100, 1)
    
    $TotalGB = [math]::Round($TotalMemory / 1MB, 2)
    $UsedGB = [math]::Round($UsedMemory / 1MB, 2)
    

    Write-Host "  Current memory usage: $MemoryPercent%" -ForegroundColor White
#Converts KB to GB in Display
    Write-Host "  Used: $UsedGB GB / Total: $TotalGB GB" -ForegroundColor White
    
#Checks Current Memory Percent against the set Memory Threshold - if above threshold 
#- 'Memory_High'
    if ($MemoryPercent -ge $MemoryThreshold) {

#Returns Alert & Logs Action     
        Write-Host "[WARNING] Memory usage above threshold ($MemoryThreshold%)" -ForegroundColor Red
        Write-Alert -AlertType "MEMORY_HIGH" -Details "usage=${MemoryPercent}% threshold=${MemoryThreshold}%"
        return $false
    } else {
        Write-Host "[SUCCESS] Memory usage normal" -ForegroundColor Green
        return $true
    }
}

#*******************************************************************************
# Function: Get-DiskUsage
#*******************************************************************************
#Checks all Disk Drives & Alerts if Any too Full

function Get-DiskUsage {
    Write-Host "`n[INFO] Checking disk usage..." -ForegroundColor Cyan

#Flag to Track Alerts    
    $AlertTriggered = $false
#Checks Drives - Drive Type 3 [Local Hard Drives C: D:] - Only fixed disks not CD-ROM, USB
    $Drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    
#Loops Through Drives
    foreach ($Drive in $Drives) {
        $DriveLetter = $Drive.DeviceID
#Retrieves Drives - DeviceID, Size, FreeSpace
        $TotalSize = [math]::Round($Drive.Size / 1GB, 2)
        $FreeSpace = [math]::Round($Drive.FreeSpace / 1GB, 2)
#Calculates Used Space & Converts to Percent
        $UsedSpace = $TotalSize - $FreeSpace
        $PercentUsed = [math]::Round(($UsedSpace / $TotalSize) * 100, 1)

#Displays Drive Usage Information        
        Write-Host "  $DriveLetter - $PercentUsed% used ($UsedSpace GB / $TotalSize GB)" -ForegroundColor White

#Compares Percent Used against Disk Threshold - if greater than Threshold - 'DISK_HIGH'     
        if ($PercentUsed -ge $DiskThreshold) {

#Alerts & Logs Action
            Write-Host "[WARNING] Disk usage on $DriveLetter above threshold ($DiskThreshold%)" -ForegroundColor Red
            Write-Alert -AlertType "DISK_HIGH" -Details "drive=$DriveLetter usage=${PercentUsed}% threshold=${DiskThreshold}%"
            $AlertTriggered = $true
        }
    }
    
    if (-not $AlertTriggered) {
        Write-Host "[SUCCESS] All disk usage normal" -ForegroundColor Green
        return $true
    }
    
    return $false
}

#*******************************************************************************
# Function: Get-TopProcesses
#*******************************************************************************
#Displays Top 5 Processes Using the Most CPU

function Get-TopProcesses {
    Write-Host "`n[INFO] Top 5 CPU-consuming processes:" -ForegroundColor Cyan

#Gets All Process - Sorts by Descending & Displays only the First 5  
    $Processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5

#Loops Through Each Process - Gets CPU Time Used (seconds) & Memory Usage    
    foreach ($Process in $Processes) {
        $CPU = [math]::Round($Process.CPU, 2)
        $MemoryMB = [math]::Round($Process.WorkingSet64 / 1MB, 2)
#Displays Process Name - CPU Time used, and Memory Usage        
        Write-Host "  $($Process.ProcessName) - CPU: $CPU sec, Memory: $MemoryMB MB" -ForegroundColor White
    }
}

#*******************************************************************************
# Function: Get-SystemInfo
#*******************************************************************************
#Displays System Information - Computer Name, OS & Uptime

function Get-SystemInfo {
    Write-Host "`n[INFO] System Information:" -ForegroundColor Cyan

#Gets OS/Computer Infor from WMI [Get-CimInstance]   
    $OS = Get-CimInstance Win32_OperatingSystem
    $Computer = Get-CimInstance Win32_ComputerSystem
    
    #Uptime - Last BootUpTime of System - 
    $Uptime = (Get-Date) - $OS.LastBootUpTime
    $UptimeString = "{0} days, {1} hours, {2} minutes" -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes

#Displays System Information    
    Write-Host "  Computer: $($Computer.Name)" -ForegroundColor White
    Write-Host "  OS: $($OS.Caption) $($OS.Version)" -ForegroundColor White
    Write-Host "  Architecture: $($OS.OSArchitecture)" -ForegroundColor White
    Write-Host "  Uptime: $UptimeString" -ForegroundColor White
}

#********************************************************************************
#Function - Start-SystemMonitor
#********************************************************************************
#Shows System Info - Checks CPU, Memory, Disk, Shows Top Processes, Display Summary
function Start-SystemMonitor {
    param(
        [switch]$Continuous, #Continous Mode
        [int]$IntervalSeconds = 60
    )
    
    do {
        Write-Host "`n=========================================" -ForegroundColor Cyan
        Write-Host " System Monitoring Report" -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        
        Get-SystemInfo
        
        $AlertCount = 0
        
        if (-not (Get-CPUUsage)) { $AlertCount++ }
        if (-not (Get-MemoryUsage)) { $AlertCount++ }
        if (-not (Get-DiskUsage)) { $AlertCount++ }
        
        Get-TopProcesses
        
        Write-Host "`n=========================================" -ForegroundColor Cyan
        Write-Host " Summary" -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        
        if ($AlertCount -eq 0) {
            Write-Host "[SUCCESS] All systems normal - no alerts triggered" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] $AlertCount alert(s) triggered - check $AlertLog" -ForegroundColor Yellow
        }
        
        Write-AuditLog -Action "SYSTEM_MONITOR" -Result "SUCCESS" -Details "alerts=$AlertCount cpu_threshold=$CPUThreshold mem_threshold=$MemoryThreshold disk_threshold=$DiskThreshold"
        
        if ($Continuous) {
            Write-Host "`n[INFO] Waiting $IntervalSeconds seconds..." -ForegroundColor Cyan
            Start-Sleep -Seconds $IntervalSeconds
        }
        
    } while ($Continuous)
}

################################################################################
# Main Script - Controller
################################################################################

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " Windows System Monitoring v1.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Running with Administrator privileges" -ForegroundColor Green

# Configuration - Diplays Set Threshold
Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  CPU threshold: $CPUThreshold%" -ForegroundColor White
Write-Host "  Memory threshold: $MemoryThreshold%" -ForegroundColor White
Write-Host "  Disk threshold: $DiskThreshold%" -ForegroundColor White
Write-Host "  Alert log: $AlertLog" -ForegroundColor White

# Parse command line arguments
$ContinuousMode = $false
$Interval = 60

# Check for -Continuous switch
if ($args -contains "-Continuous") {
    $ContinuousMode = $true
    $IntervalIndex = [array]::IndexOf($args, "-Interval")
    if ($IntervalIndex -ge 0 -and $IntervalIndex + 1 -lt $args.Count) {
        $Interval = [int]$args[$IntervalIndex + 1]
    }
}

# Run monitoring
Start-SystemMonitor -Continuous:$ContinuousMode -IntervalSeconds $Interval
