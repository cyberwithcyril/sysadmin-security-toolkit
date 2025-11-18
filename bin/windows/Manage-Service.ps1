<#*****************************************************************************
.SYNOPSIS
    Windows service management script
.DESCRIPTION
    Manages Windows Services - List all Services, Show info, Start/Stop/Restart 
    Change Startup Type [Automatic/Manual/Disabled]
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    1.0
*******************************************************************************#>

#Requires -RunAsAdministrator

# Configuration
$AuditLog = "C:\Logs\SysAdminToolkit\audit.log"
$LogDir = "C:\Logs\SysAdminToolkit"

#*******************************************************************************
# Function: Write-AuditLog
#*******************************************************************************
#Logs Actions to Audit File

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
# Function: Test-Administrator
#*******************************************************************************
#Checks if running as Admin
function Test-Administrator {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#******************************************************************************
# Function: Get-ServiceList
#******************************************************************************
#Lists all Windows Services [Running & Stopped]

function Get-ServiceList {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Windows Services" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`nRunning Services:" -ForegroundColor Green

#Retrieves all services where status is running [First 20] - Displays as table 
#- [Name, DisplayName, Status]
    Get-Service | Where-Object {$_.Status -eq 'Running'} | 
        Select-Object -First 20 | 
        Format-Table Name, DisplayName, Status -AutoSize

#Retrieves all services where status is stopped [First 10] - Displays as table 
#- [Name, DisplayName, Status]    
    Write-Host "`nStopped Services:" -ForegroundColor Yellow
    Get-Service | Where-Object {$_.Status -eq 'Stopped'} | 
        Select-Object -First 10 | 
        Format-Table Name, DisplayName, Status -AutoSize

#Gets Total Count of All Running Services 
    $RunningCount = (Get-Service | Where-Object {$_.Status -eq 'Running'}).Count
#Gets Total Count of All Stopped Services
    $StoppedCount = (Get-Service | Where-Object {$_.Status -eq 'Stopped'}).Count
    
    Write-Host "Total: $RunningCount running, $StoppedCount stopped" -ForegroundColor White
}

#*******************************************************************************
# Function: Get-ServiceInfo
#*******************************************************************************
# Shows detailed information about a specific service

function Get-ServiceInfo {
    param([string]$ServiceName)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Service Information: $ServiceName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    try {
#Gets specific service by name
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
#Displays Service Name, Display Name, Service Status, and Starttype        
        Write-Host "`nBasic Information:" -ForegroundColor Yellow
        Write-Host "  Name: $($Service.Name)" -ForegroundColor White
        Write-Host "  Display Name: $($Service.DisplayName)" -ForegroundColor White
        Write-Host "  Status: $($Service.Status)" -ForegroundColor $(if ($Service.Status -eq 'Running') { 'Green' } else { 'Red' })
        Write-Host "  Start Type: $($Service.StartType)" -ForegroundColor White
        
#Retrieves WMI Information using 'Get-CimInstance' - Query Windows Management Instrumentation
#WMI contains Process ID, Path & Additional Description
        $WMIService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'"

#Displays Process ID, Path, & Description of Service       
        if ($WMIService) {
            Write-Host "`nAdditional Details:" -ForegroundColor Yellow
            Write-Host "  Process ID: $($WMIService.ProcessId)" -ForegroundColor White
            Write-Host "  Path: $($WMIService.PathName)" -ForegroundColor White
            Write-Host "  Description: $($WMIService.Description)" -ForegroundColor White
        }
        
#Checks Dependencies needed for the Service
        $Dependencies = $Service.ServicesDependedOn

#If Dependencies are greater than 0 - Display all Dependencies [Name/Status]
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

#******************************************************************************
# Function: Start-ServiceSafe
#******************************************************************************
#Starts a Windows Service Safely

function Start-ServiceSafe {
    param([string]$ServiceName)
    
    Write-Host "`n[INFO] Starting service: $ServiceName" -ForegroundColor Cyan
    
    try {

        $Service = Get-Service -Name $ServiceName -ErrorAction Stop

#Checks if Service is Running        
        if ($Service.Status -eq 'Running') {
            Write-Host "[INFO] Service is already running" -ForegroundColor Yellow
            return $true
        }
#Starts Service - PS [Start-Serivce]        
        Start-Service -Name $ServiceName -ErrorAction Stop
#Sets Service Time to Start
        Start-Sleep -Seconds 2

#Checks/Validates Service is Running       
        $Service = Get-Service -Name $ServiceName
        if ($Service.Status -eq 'Running') {
            Write-Host "[SUCCESS] Service started successfully" -ForegroundColor Green
#Logs Action - Success/Failure
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

#******************************************************************************
# Function: Stop-ServiceSafe
#******************************************************************************
#Stops a Windows Service Safely

function Stop-ServiceSafe {
    param([string]$ServiceName)
    
    Write-Host "`n[INFO] Stopping service: $ServiceName" -ForegroundColor Cyan
    
    try {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
#Checks if Service Status is 'Stopped'        
        if ($Service.Status -eq 'Stopped') {
            Write-Host "[INFO] Service is already stopped" -ForegroundColor Yellow
            return $true
        }
#Stops Service using PS [Stop-Service]        
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
#Sets Time for Service to Stop -2 seconds
        Start-Sleep -Seconds 2
        
#Checks/Validates Service Status 'Stopped'
        $Service = Get-Service -Name $ServiceName
        if ($Service.Status -eq 'Stopped') {
            Write-Host "[SUCCESS] Service stopped successfully" -ForegroundColor Green
#Logs Action - Success/Failure
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

#*******************************************************************************
# Function: Restart-ServiceSafe
#*******************************************************************************
#Restarts Service Safely - Stops Then Starts

function Restart-ServiceSafe {
    param([string]$ServiceName)
    
    Write-Host "`n[INFO] Restarting service: $ServiceName" -ForegroundColor Cyan
    
    try {

#Restarts Service using PS[Restart-Service]
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
#Sets Time for Stop Restart - 2seconds
        Start-Sleep -Seconds 2
        
        $Service = Get-Service -Name $ServiceName
#Checks/Validates Service is Running
        if ($Service.Status -eq 'Running') {
            Write-Host "[SUCCESS] Service restarted successfully" -ForegroundColor Green
#Logs Action - Success/Failure
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

#*******************************************************************************
# Function: Set-ServiceStartup
#*******************************************************************************
#Changes how a service starts - [Automatic, Manual, Disabled]
function Set-ServiceStartup {
    param(
        [string]$ServiceName,
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [string]$StartupType
    )
    
    Write-Host "`n[INFO] Setting startup type for $ServiceName to $StartupType" -ForegroundColor Cyan
    
    try {

#Changes Startup Type using PS [Set-Service -StartupType]
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
        Write-Host "[SUCCESS] Startup type changed to $StartupType" -ForegroundColor Green
#Logs Action - Success/Failure      
        Write-AuditLog -Action "SERVICE_STARTUP_CHANGE" -Result "SUCCESS" -Details "service=$ServiceName startup=$StartupType"
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to change startup type: $_" -ForegroundColor Red
        Write-AuditLog -Action "SERVICE_STARTUP_CHANGE" -Result "FAILURE" -Details "service=$ServiceName error=$($_.Exception.Message)"
        return $false
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

# Main menu loop
while ($true) {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host " Windows Service Management v1.0" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. List all services" -ForegroundColor Yellow
    Write-Host "2. Show service details" -ForegroundColor Yellow
    Write-Host "3. Start a service" -ForegroundColor Yellow
    Write-Host "4. Stop a service" -ForegroundColor Yellow
    Write-Host "5. Restart a service" -ForegroundColor Yellow
    Write-Host "6. Change service startup type" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "0. Exit to main menu" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            Get-ServiceList
            Read-Host "`nPress Enter to continue"
        }
        "2" {
            $serviceName = Read-Host "`nEnter service name"
            Get-ServiceInfo -ServiceName $serviceName
            Read-Host "`nPress Enter to continue"
        }
        "3" {
            $serviceName = Read-Host "`nEnter service name to start"
            Start-ServiceSafe -ServiceName $serviceName
            Read-Host "`nPress Enter to continue"
        }
        "4" {
            $serviceName = Read-Host "`nEnter service name to stop"
            Stop-ServiceSafe -ServiceName $serviceName
            Read-Host "`nPress Enter to continue"
        }
        "5" {
            $serviceName = Read-Host "`nEnter service name to restart"
            Restart-ServiceSafe -ServiceName $serviceName
            Read-Host "`nPress Enter to continue"
        }
        "6" {
            $serviceName = Read-Host "`nEnter service name"
            Write-Host "`nStartup Types:" -ForegroundColor Cyan
            Write-Host "  1. Automatic"
            Write-Host "  2. Manual"
            Write-Host "  3. Disabled"
            $typeChoice = Read-Host "`nSelect startup type (1-3)"
            
            $startupType = switch ($typeChoice) {
                "1" { "Automatic" }
                "2" { "Manual" }
                "3" { "Disabled" }
                default { "Manual" }
            }
            
            Set-ServiceStartup -ServiceName $serviceName -StartupType $startupType
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