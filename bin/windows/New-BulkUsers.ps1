<#*******************************************************************************
.SYNOPSIS
    Windows Bulk User Creation with Enforced Security Policies
.DESCRIPTION
    Creates Windows Local User Accounts with Security Policies
.AUTHOR
    Cyril Thomas
.DATE
    November 5, 2025
.VERSION
    2.0
*******************************************************************************#>

#Requires -RunAsAdministrator

# Configuration
$AuditLog = "C:\Logs\SysAdminToolkit\audit.log"
$LogDir = "C:\Logs\SysAdminToolkit"

#********************************************************************************
# Function: Write-AuditLog
#********************************************************************************
# Write-AuditLog
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

#*********************************************************************************
# Function: Test-Administrator
#*********************************************************************************
#Checks if Adminstrator
function Test-Administrator {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#********************************************************************************
# Function: New-LocalUserAccount
#********************************************************************************
#Creates a single Windows Local user account with security settings
function New-LocalUserAccount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username, #Login Name
        
        [Parameter(Mandatory=$true)]
        [string]$FullName, #Full Name
        
        [string]$Description = "Created by automation", #Account Description Not Required
        
        [string[]]$Groups = @("Users") #Array of Groups - Default: Users
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Creating User: $Username" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
#Checks if User Exists - [Get-LocalUser]
    try {
        $ExistingUser = Get-LocalUser -Name $Username -ErrorAction Stop
        Write-Host "[ERROR] User already exists: $Username" -ForegroundColor Red
#Logs Action       
        Write-AuditLog -Action "USER_CREATE" -Result "FAILURE" -Details "username=$Username error=already_exists"
        return $false
    }
    catch {
        # User doesn't exist, continue
    }
    
#Generate Secure Password - Load .Net Library[Password Generator][Add-Type -AssemblyName System.Web]
    Add-Type -AssemblyName System.Web

#Generates Temp Password [.NET method - 16 characters, atleast 4 special chars,]\
#using [System.Web.Security.Membership]
    $TempPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4) #Plain text
    $SecurePassword = ConvertTo-SecureString $TempPassword -AsPlainText -Force #Encrypted
    
    try {
#Creates New User using PS[New-LocalUser] - using username, password, fullname, description
#Sets PaswordNeverExpires to false, UseMayNotChangePassword to false, and Account Never Expires
#to false
        New-LocalUser -Name $Username `
                      -Password $SecurePassword `
                      -FullName $FullName `
                      -Description $Description `
                      -PasswordNeverExpires:$false `
                      -UserMayNotChangePassword:$false `
                      -AccountNeverExpires:$false | Out-Null
        
        Write-Host "[SUCCESS] User account created" -ForegroundColor Green
        
#Sets Password Policy
        $User = Get-LocalUser -Name $Username
        
#Ensures password expires on first login
        $User | Set-LocalUser -PasswordNeverExpires $false
        Write-Host "[SUCCESS] Password change required on first login" -ForegroundColor Green

        Write-Host "[INFO] Password policies: Must change on first login" -ForegroundColor Yellow
        
#Add to Groups
        $GroupsAdded = @()
        foreach ($Group in $Groups) {
            try {

#Checks If Group Exists

                $GroupExists = Get-LocalGroup -Name $Group -ErrorAction Stop
#Adds User to Group
                Add-LocalGroupMember -Group $Group -Member $Username -ErrorAction Stop
                Write-Host "[SUCCESS] Added to group: $Group" -ForegroundColor Green
                $GroupsAdded += $Group
            }

#If Group Does Not Exists/or if Already a Member of That Group
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
#Adds Action to Log        
        Write-AuditLog -Action "USER_CREATE" -Result "SUCCESS" -Details "username=$Username fullname='$FullName' groups=$($GroupsAdded -join ',')"

#Displays User Creation        
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

#*********************************************************************************
# Function: Import-UsersFromCSV
#*********************************************************************************
#Creates multiple users from a CSV File

function Import-UsersFromCSV {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVPath,
        
        [string]$DefaultGroup = "Users"
    )

#Check if CSV Path exists
    if (-not (Test-Path $CSVPath)) {
        Write-Host "[ERROR] CSV file not found: $CSVPath" -ForegroundColor Red
        return
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Bulk User Creation from CSV" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "CSV File: $CSVPath" -ForegroundColor Cyan
    Write-Host ""

#Import CSV Path   
    $Users = Import-Csv -Path $CSVPath
#Counters - Successful Imports/Failed Imports & Total Count of Users
    $SuccessCount = 0
    $FailCount = 0
    $Total = $Users.Count
    
    Write-Host "Processing $Total users..." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($User in $Users) {
        Write-Host "Processing: $($User.username) ($($User.full_name))" -ForegroundColor White
        
 #Deternmines Groups - Uses Default Group: Users or  Department if Available 
        $UserGroups = @($DefaultGroup)
        if ($User.department) {
            $UserGroups += $User.department
        }
#Creates User [New-LocalUserAccount]       
        $Result = New-LocalUserAccount -Username $User.username `
                                       -FullName $User.full_name `
                                       -Description "Department: $($User.department), Role: $($User.role)" `
                                       -Groups $UserGroups
#Increments Counters & Displays Success/Failed        
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
#Adds Action to Log   
    Write-AuditLog -Action "BULK_USER_CREATE" -Result "SUCCESS" -Details "total=$Total success=$SuccessCount failed=$FailCount"
}

#**********************************************************************************
# Main Script - Controller
#***********************************************************************************

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
