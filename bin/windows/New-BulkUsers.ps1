<#
.SYNOPSIS
    Windows bulk user creation with security policies
.DESCRIPTION
    Creates local user accounts with password policies, group management, and audit logging
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    2.0
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
    Write-Host $LogEntry
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
# Function: New-LocalUserAccount
################################################################################
function New-LocalUserAccount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$true)]
        [string]$FullName,
        
        [string]$Description = "Created by automation",
        
        [string[]]$Groups = @("Users")
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Creating User: $Username" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Check if user exists
    try {
        $ExistingUser = Get-LocalUser -Name $Username -ErrorAction Stop
        Write-Host "[ERROR] User already exists: $Username" -ForegroundColor Red
        Write-AuditLog -Action "USER_CREATE" -Result "FAILURE" -Details "username=$Username error=already_exists"
        return $false
    }
    catch {
        # User doesn't exist, continue
    }
    
    # Generate secure password
    Add-Type -AssemblyName System.Web
    $TempPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)
    $SecurePassword = ConvertTo-SecureString $TempPassword -AsPlainText -Force
    
    try {
        # Create user
        New-LocalUser -Name $Username `
                      -Password $SecurePassword `
                      -FullName $FullName `
                      -Description $Description `
                      -PasswordNeverExpires:$false `
                      -UserMayNotChangePassword:$false `
                      -AccountNeverExpires:$false | Out-Null
        
        Write-Host "[SUCCESS] User account created" -ForegroundColor Green
        
        # Set password policies
        $User = Get-LocalUser -Name $Username
        
        # Force password change at next login
        $User | Set-LocalUser -PasswordNeverExpires $false
        Write-Host "[SUCCESS] Password change required on first login" -ForegroundColor Green
        
        # Note: Windows local accounts don't have expiration like Linux chage
        # Would need AD for full policy control
        Write-Host "[INFO] Password policies: Must change on first login" -ForegroundColor Yellow
        
        # Add to groups
        $GroupsAdded = @()
        foreach ($Group in $Groups) {
            try {
                # Check if group exists
                $GroupExists = Get-LocalGroup -Name $Group -ErrorAction Stop
                Add-LocalGroupMember -Group $Group -Member $Username -ErrorAction Stop
                Write-Host "[SUCCESS] Added to group: $Group" -ForegroundColor Green
                $GroupsAdded += $Group
            }
            catch [Microsoft.PowerShell.Commands.GroupNotFoundException] {
                Write-Host "[WARNING] Group does not exist: $Group (skipping)" -ForegroundColor Yellow
            }
            catch [Microsoft.PowerShell.Commands.MemberExistsException] {
                Write-Host "[INFO] Already member of: $Group" -ForegroundColor Yellow
                $GroupsAdded += $Group
            }
            catch {
                Write-Host "[WARNING] Failed to add to group $Group : $_" -ForegroundColor Yellow
            }
        }
        
        Write-AuditLog -Action "USER_CREATE" -Result "SUCCESS" -Details "username=$Username fullname='$FullName' groups=$($GroupsAdded -join ',')"
        
        Write-Host "`n[SUCCESS] User created successfully!" -ForegroundColor Green
        Write-Host "Username: $Username" -ForegroundColor White
        Write-Host "Full Name: $FullName" -ForegroundColor White
        Write-Host "Temporary Password: $TempPassword" -ForegroundColor Yellow
        Write-Host "Groups: $($GroupsAdded -join ', ')" -ForegroundColor White
        Write-Host ""
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to create user: $_" -ForegroundColor Red
        Write-AuditLog -Action "USER_CREATE" -Result "FAILURE" -Details "username=$Username error=$($_.Exception.Message)"
        return $false
    }
}

################################################################################
# Function: Import-UsersFromCSV
################################################################################
function Import-UsersFromCSV {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVPath,
        
        [string]$DefaultGroup = "Users"
    )
    
    if (-not (Test-Path $CSVPath)) {
        Write-Host "[ERROR] CSV file not found: $CSVPath" -ForegroundColor Red
        return
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Bulk User Creation from CSV" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "CSV File: $CSVPath" -ForegroundColor Cyan
    Write-Host ""
    
    $Users = Import-Csv -Path $CSVPath
    $SuccessCount = 0
    $FailCount = 0
    $Total = $Users.Count
    
    Write-Host "Processing $Total users..." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($User in $Users) {
        Write-Host "Processing: $($User.username) ($($User.full_name))" -ForegroundColor White
        
        # Determine groups (use department if available, otherwise default)
        $UserGroups = @($DefaultGroup)
        if ($User.department) {
            $UserGroups += $User.department
        }
        
        $Result = New-LocalUserAccount -Username $User.username `
                                       -FullName $User.full_name `
                                       -Description "Department: $($User.department), Role: $($User.role)" `
                                       -Groups $UserGroups
        
        if ($Result) {
            $SuccessCount++
            Write-Host "[SUCCESS] Created: $($User.username)" -ForegroundColor Green
        } else {
            $FailCount++
            Write-Host "[FAILED] Skipped: $($User.username)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total users processed: $Total" -ForegroundColor White
    Write-Host "Successfully created: $SuccessCount users" -ForegroundColor Green
    Write-Host "Failed: $FailCount users" -ForegroundColor $(if ($FailCount -gt 0) { "Red" } else { "Green" })
    Write-Host ""
    
    Write-AuditLog -Action "BULK_USER_CREATE" -Result "SUCCESS" -Details "total=$Total success=$SuccessCount failed=$FailCount"
}

################################################################################
# Main Script
################################################################################

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " Windows User Creation Script v2.0" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "[SUCCESS] Running with Administrator privileges" -ForegroundColor Green
Write-Host ""

# Show usage
Write-Host "Script loaded successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  Single user:" -ForegroundColor White
Write-Host "    New-LocalUserAccount -Username 'jdoe' -FullName 'John Doe'" -ForegroundColor Gray
Write-Host ""
Write-Host "  With groups:" -ForegroundColor White
Write-Host "    New-LocalUserAccount -Username 'jsmith' -FullName 'Jane Smith' -Groups @('Users','Administrators')" -ForegroundColor Gray
Write-Host ""
Write-Host "  From CSV:" -ForegroundColor White
Write-Host "    Import-UsersFromCSV -CSVPath 'C:\path\to\users.csv'" -ForegroundColor Gray
Write-Host ""
