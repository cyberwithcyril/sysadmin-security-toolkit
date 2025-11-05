<#
.SYNOPSIS
    Windows service management script
.DESCRIPTION
    Start, stop, restart, and manage Windows services
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    1.0
#>

#Requires -RunAsAdministrator

# Configuration
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
# Function: Get-ServiceList
################################################################################
function Get-ServiceList {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Windows Services" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`nRunning Services:" -ForegroundColor Green
    Get-Service | Where-Object {$_.Status -eq 'Running'} | 
        Select-Object -First 20 | 
        Format-Table Name, DisplayName, Status -AutoSize
    
    Write-Host "`nStopped Services:" -ForegroundColor Yellow
    Get-Service | Where-Object {$_.Status -eq 'Stopped'} | 
        Select-Object -First 10 | 
        Format-Table Name, DisplayName, Status -AutoSize
    
    $RunningCount = (Get-Service | Where-Object {$_.Status -eq 'Running'}).Count
    $StoppedCount = (Get-Service | Where-Object {$_.Status -eq 'Stopped'}).Count
    
    Write-Host "Total: $RunningCount running, $StoppedCount stopped" -ForegroundColor White
}

################################################################################
# Function: Get-ServiceInfo
################################################################################
function Get-ServiceInfo {
    param([string]$ServiceName)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Service Information: $ServiceName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    try {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
        
        Write-Host "`nBasic Information:" -ForegroundColor Yellow
        Write-Host "  Name: $($Service.Name)" -ForegroundColor White
        Write-Host "  Display Name: $($Service.DisplayName)" -ForegroundColor White
        Write-Host "  Status: $($Service.Status)" -ForegroundColor $(if ($Service.Status -eq 'Running') { 'Green' } else { 'Red' })
        Write-Host "  Start Type: $($Service.StartType)" -ForegroundColor White
        
        # Get WMI info for more details
        $WMIService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'"
        if ($WMIService) {
            Write-Host "`nAdditional Details:" -ForegroundColor Yellow
            Write-Host "  Process ID: $($WMIService.ProcessId)" -ForegroundColor White
            Write-Host "  Path: $($WMIService.PathName)" -ForegroundColor White
            Write-Host "  Description: $($WMIService.Description)" -ForegroundColor White
        }
        
        # Check dependencies
        $Dependencies = $Service.ServicesDependedOn
        if ($Dependencies.Count -gt 0) {
            Write-Host "`nDepends On:" -ForegroundColor Yellow
            $Dependencies | ForEach-Object {
                Write-Host "  - $($_.Name) ($($_.Status))" -ForegroundColor White
            }
        }
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Service not found: $ServiceName" -ForegroundColor Red
        return $false
    }
}

################################################################################
# Function: Start-ServiceSafe
################################################################################
function Start-ServiceSafe {
    param([string]$ServiceName)
    
    Write-Host "`n[INFO] Starting service: $ServiceName" -ForegroundColor Cyan
    
    try {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
        
        if ($Service.Status -eq 'Running') {
            Write-Host "[INFO] Service is already running" -ForegroundColor Yellow
            return $true
        }
        
        Start-Service -Name $ServiceName -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        $Service = Get-Service -Name $ServiceName
        if ($Service.Status -eq 'Running') {
            Write-Host "[SUCCESS] Service started successfully" -ForegroundColor Green
            Write-AuditLog -Action "SERVICE_START" -Result "SUCCESS" -Details "service=$ServiceName"
            return $true
        } else {
            Write-Host "[ERROR] Service failed to start" -ForegroundColor Red
            Write-AuditLog -Action "SERVICE_START" -Result "FAILURE" -Details "service=$ServiceName"
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Failed to start service: $_" -ForegroundColor Red
        Write-AuditLog -Action "SERVICE_START" -Result "FAILURE" -Details "service=$ServiceName error=$($_.Exception.Message)"
        return $false
    }
}

################################################################################
# Function: Stop-ServiceSafe
################################################################################
function Stop-ServiceSafe {
    param([string]$ServiceName)
    
    Write-Host "`n[INFO] Stopping service: $ServiceName" -ForegroundColor Cyan
    
    try {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
        
        if ($Service.Status -eq 'Stopped') {
            Write-Host "[INFO] Service is already stopped" -ForegroundColor Yellow
            return $true
        }
        
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        $Service = Get-Service -Name $ServiceName
        if ($Service.Status -eq 'Stopped') {
            Write-Host "[SUCCESS] Service stopped successfully" -ForegroundColor Green
            Write-AuditLog -Action "SERVICE_STOP" -Result "SUCCESS" -Details "service=$ServiceName"
            return $true
        } else {
            Write-Host "[ERROR] Service failed to stop" -ForegroundColor Red
            Write-AuditLog -Action "SERVICE_STOP" -Result "FAILURE" -Details "service=$ServiceName"
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Failed to stop service: $_" -ForegroundColor Red
        Write-AuditLog -Action "SERVICE_STOP" -Result "FAILURE" -Details "service=$ServiceName error=$($_.Exception.Message)"
        return $false
    }
}

################################################################################
# Function: Restart-ServiceSafe
################################################################################
function Restart-ServiceSafe {
    param([string]$ServiceName)
    
    Write-Host "`n[INFO] Restarting service: $ServiceName" -ForegroundColor Cyan
    
    try {
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        $Service = Get-Service -Name $ServiceName
        if ($Service.Status -eq 'Running') {
            Write-Host "[SUCCESS] Service restarted successfully" -ForegroundColor Green
            Write-AuditLog -Action "SERVICE_RESTART" -Result "SUCCESS" -Details "service=$ServiceName"
            return $true
        } else {
            Write-Host "[ERROR] Service failed to restart" -ForegroundColor Red
            Write-AuditLog -Action "SERVICE_RESTART" -Result "FAILURE" -Details "service=$ServiceName"
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Failed to restart service: $_" -ForegroundColor Red
        Write-AuditLog -Action "SERVICE_RESTART" -Result "FAILURE" -Details "service=$ServiceName error=$($_.Exception.Message)"
        return $false
    }
}

################################################################################
# Function: Set-ServiceStartup
################################################################################
function Set-ServiceStartup {
    param(
        [string]$ServiceName,
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [string]$StartupType
    )
    
    Write-Host "`n[INFO] Setting startup type for $ServiceName to $StartupType" -ForegroundColor Cyan
    
    try {
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
        Write-Host "[SUCCESS] Startup type changed to $StartupType" -ForegroundColor Green
        Write-AuditLog -Action "SERVICE_STARTUP_CHANGE" -Result "SUCCESS" -Details "service=$ServiceName startup=$StartupType"
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to change startup type: $_" -ForegroundColor Red
        Write-AuditLog -Action "SERVICE_STARTUP_CHANGE" -Result "FAILURE" -Details "service=$ServiceName error=$($_.Exception.Message)"
        return $false
    }
}

################################################################################
# Main Script
################################################################################

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " Windows Service Management v1.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Running with Administrator privileges" -ForegroundColor Green

# Show usage
Write-Host "`nScript loaded successfully!" -ForegroundColor Green
Write-Host "`nAvailable Commands:" -ForegroundColor Yellow
Write-Host "  Get-ServiceList                           # List all services" -ForegroundColor Gray
Write-Host "  Get-ServiceInfo -ServiceName 'Spooler'    # Show service details" -ForegroundColor Gray
Write-Host "  Start-ServiceSafe -ServiceName 'Spooler'  # Start a service" -ForegroundColor Gray
Write-Host "  Stop-ServiceSafe -ServiceName 'Spooler'   # Stop a service" -ForegroundColor Gray
Write-Host "  Restart-ServiceSafe -ServiceName 'Spooler' # Restart a service" -ForegroundColor Gray
Write-Host "  Set-ServiceStartup -ServiceName 'Spooler' -StartupType 'Automatic' # Change startup" -ForegroundColor Gray
Write-Host ""
