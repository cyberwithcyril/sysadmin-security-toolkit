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
#Measures CPU-Usage and Alerts if Too High
function Get-CPUUsage {
    Write-Host "`n[INFO] Checking CPU usage..." -ForegroundColor Cyan
    
    try {
        #Get CPU usage using Performance Counters - Measures over 2 seconds for accuracy
        #Takes measurement, waits 2 seconds, takes second measurement for real average
        Write-Host "  Measuring CPU over 2 seconds..." -ForegroundColor Gray
        
        # First measurement
        $cpu1 = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
        Start-Sleep -Seconds 2
        # Second measurement
        $cpu2 = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
        
        $CPUUsage = [math]::Round($cpu2.PercentProcessorTime, 1)
        
        # Validation: If reading is 0%, something is wrong - use backup method
        if ($CPUUsage -eq 0) {
            throw "Zero reading detected, using alternative method"
        }
    }
    catch {
        #Fallback Method 1: Try PS[Get-Counter] Windows Performance Counters
        #Takes 3 Samples and Gets the Average
        Write-Host "[INFO] Using Performance Counter method..." -ForegroundColor Yellow
        
        try {
            $counter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3 -ErrorAction Stop
            $CPUUsage = [math]::Round(($counter.CounterSamples | Measure-Object -Property CookedValue -Average).Average, 1)
        }
        catch {
            #Fallback Method 2: Use WMI if Performance Counter fails (most reliable on some systems)
            Write-Host "[INFO] Using basic CPU measurement..." -ForegroundColor Yellow
            
            $CpuLoad = Get-CimInstance -ClassName Win32_Processor | 
                       Measure-Object -Property LoadPercentage -Average | 
                       Select-Object -ExpandProperty Average
            
            $CPUUsage = [math]::Round($CpuLoad, 1)
        }
    }
    
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

# Display System Information    
    Write-Host "`n[SYSTEM]" -ForegroundColor Yellow
    Write-Host "  Hostname: $($Computer.Name)" -ForegroundColor White
    Write-Host "  Domain: $($Computer.Domain)" -ForegroundColor White
    Write-Host "  Manufacturer: $($Computer.Manufacturer)" -ForegroundColor White
    Write-Host "  Model: $($Computer.Model)" -ForegroundColor White
    
    Write-Host "`n[OPERATING SYSTEM]" -ForegroundColor Yellow
    Write-Host "  OS: $($OS.Caption)" -ForegroundColor White
    Write-Host "  Version: $($OS.Version)" -ForegroundColor White
    Write-Host "  Build: $($OS.BuildNumber)" -ForegroundColor White
    Write-Host "  Architecture: $($OS.OSArchitecture)" -ForegroundColor White
    Write-Host "  Install Date: $($OS.InstallDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
    Write-Host "  Uptime: $UptimeString" -ForegroundColor White
    
    Write-Host "`n[PROCESSOR]" -ForegroundColor Yellow
    Write-Host "  CPU: $($Processor.Name)" -ForegroundColor White
    Write-Host "  Cores: $($Processor.NumberOfCores)" -ForegroundColor White
    Write-Host "  Logical Processors: $($Processor.NumberOfLogicalProcessors)" -ForegroundColor White
    
    Write-Host "`n[MEMORY]" -ForegroundColor Yellow
    $TotalRAM = [math]::Round($Computer.TotalPhysicalMemory / 1GB, 2)
    $FreeRAM = [math]::Round($OS.FreePhysicalMemory / 1MB / 1024, 2)
    $UsedRAM = [math]::Round($TotalRAM - $FreeRAM, 2)
    $RAMPercent = [math]::Round(($UsedRAM / $TotalRAM) * 100, 1)
    
    Write-Host "  Total RAM: $TotalRAM GB" -ForegroundColor White
    Write-Host "  Used RAM: $UsedRAM GB ($RAMPercent%)" -ForegroundColor White
    Write-Host "  Free RAM: $FreeRAM GB" -ForegroundColor White
    
    Write-Host "`n[DISK]" -ForegroundColor Yellow
    $Drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    foreach ($Drive in $Drives) {
        $Size = [math]::Round($Drive.Size / 1GB, 2)
        $Free = [math]::Round($Drive.FreeSpace / 1GB, 2)
        $Used = $Size - $Free
        $Percent = [math]::Round(($Used / $Size) * 100, 1)
        
        Write-Host "  Drive $($Drive.DeviceID) - $Percent% used ($Used GB / $Size GB)" -ForegroundColor White
    }
    
    Write-Host "`n[NETWORK]" -ForegroundColor Yellow
    $Network = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" 
    } | Select-Object -First 1
    
    if ($Network) {
        Write-Host "  IP Address: $($Network.IPAddress)" -ForegroundColor White
        Write-Host "  Interface: $($Network.InterfaceAlias)" -ForegroundColor White
        
        # Get Gateway
        $Gateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -First 1
        if ($Gateway) {
            Write-Host "  Gateway: $($Gateway.NextHop)" -ForegroundColor White
        }
    }
    
    Write-Host ""
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
#*******************************************************************************
# Function: View-SystemAuditLogs
#*******************************************************************************
# View system audit logs from C:\SystemAudit\AuditLogs\

function View-SystemAuditLogs {
    $auditDir = "C:\SystemAudit\AuditLogs"
    
    if (!(Test-Path $auditDir)) {
        Write-Host "`n[INFO] No system audit logs found." -ForegroundColor Yellow
        Write-Host "[INFO] Run the System-AuditLog.ps1 script first to generate audit logs." -ForegroundColor Yellow
        return
    }
    
    Clear-Host
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host " System Audit Logs" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    Write-Host "`nAvailable Audit Logs:" -ForegroundColor Yellow
    $logs = Get-ChildItem $auditDir -Filter "*.log" | Sort-Object LastWriteTime -Descending
    
    if ($logs.Count -eq 0) {
        Write-Host "[INFO] No audit log files found in $auditDir" -ForegroundColor Yellow
        return
    }
    
#Display logs in a numbered list
    for ($i = 0; $i -lt $logs.Count; $i++) {
        $log = $logs[$i]
        $size = [math]::Round($log.Length / 1KB, 2)
        Write-Host "  $($i+1). $($log.Name) - $($log.LastWriteTime) - $size KB" -ForegroundColor White
    }
    
    Write-Host "`nOptions:" -ForegroundColor Yellow
    Write-Host "  Enter number to view specific log" -ForegroundColor White
    Write-Host "  Type 'latest' for most recent log" -ForegroundColor White
    Write-Host "  Type '0' to return to menu" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select option"
    
    if ($choice -eq "0") {
        return
    }
    elseif ($choice -eq "latest") {
        $selectedLog = $logs[0]
        Clear-Host
        Write-Host "`n=========================================" -ForegroundColor Cyan
        Write-Host " Viewing: $($selectedLog.Name)" -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Get-Content $selectedLog.FullName | Out-Host -Paging
    }
    elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $logs.Count) {
        $selectedLog = $logs[[int]$choice - 1]
        Clear-Host
        Write-Host "`n=========================================" -ForegroundColor Cyan
        Write-Host " Viewing: $($selectedLog.Name)" -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Get-Content $selectedLog.FullName | Out-Host -Paging
    }
    else {
        Write-Host "`n[ERROR] Invalid selection" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

#*******************************************************************************
# Main Script - Interactive Menu
#*******************************************************************************

# Check Administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Running with Administrator privileges" -ForegroundColor Green

# Main menu loop
while ($true) {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host " Windows System Monitoring v1.0" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current Thresholds:" -ForegroundColor Yellow
    Write-Host "  CPU: $CPUThreshold%" -ForegroundColor White
    Write-Host "  Memory: $MemoryThreshold%" -ForegroundColor White
    Write-Host "  Disk: $DiskThreshold%" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Run single system check" -ForegroundColor Yellow
    Write-Host "2. Start continuous monitoring (60 sec interval)" -ForegroundColor Yellow
    Write-Host "3. View alert log" -ForegroundColor Yellow
    Write-Host "4. View audit log" -ForegroundColor Yellow
    Write-Host "5. View system audit logs" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "0. Exit to main menu" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            Clear-Host
            Start-SystemMonitor -Continuous:$false
            Read-Host "`nPress Enter to continue"
        }
        "2" {
            Clear-Host
            Write-Host "[INFO] Starting continuous monitoring..." -ForegroundColor Cyan
            Write-Host "[INFO] Press Ctrl+C to stop" -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds 2
            Start-SystemMonitor -Continuous -IntervalSeconds 60
        }
        "3" {
            Clear-Host
            Write-Host "`n=========================================" -ForegroundColor Cyan
            Write-Host " Alert Log" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            if (Test-Path $AlertLog) {
                Get-Content $AlertLog -Tail 20
            } else {
                Write-Host "[INFO] No alerts logged yet" -ForegroundColor Yellow
            }
            Read-Host "`nPress Enter to continue"
        }
        "4" {
            Clear-Host
            Write-Host "`n=========================================" -ForegroundColor Cyan
            Write-Host " Audit Log" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            if (Test-Path $AuditLog) {
                Get-Content $AuditLog -Tail 20
            } else {
                Write-Host "[INFO] No audit entries yet" -ForegroundColor Yellow
            }
            Read-Host "`nPress Enter to continue"
        }
        "5" {
            View-SystemAuditLogs
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