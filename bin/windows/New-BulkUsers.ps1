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

#****************************************************************************************
# Function: Disable User Account
#****************************************************************************************
function Disable-LocalUserAccount{
    param(
        [Parameter(Mandatory=$true)]
        [string]$username,

        [Parameter(Mandatory=$false)]
        [string]$Reason = "Account Disabled by Administrator"
    )

    Write-Host "'n======================================================" -ForegroundColor Cyan
    Write-Host "  Disabling User: $Username" - ForegroundColor Cyan
    Write-Host "=========================================================="
    

    #Check if user exists

    try {
        $user = Get-LocalUser -Name $Usernmae -ErrorAction Stop
    }
    catch {
        Write-Host "[ERROR] User '$Usernmae' does not exist" - ForegroundColor Red
        Write-AuditLog -Action "USER_DISABLE" -Result "FAILURE" -Details
         "username=$Username error=user_not_found"
        return $false
    }

    #Check if user is already disabled

    if(-not $user.Enabled){
        Write-Host "[WARNING] User '$Username is already disabled" -ForegroundColor Yellow  
        return $true
}

#Prevent Disabling Administrator or Current User

if ($Username -eq "Administrator" -or $Username -eq $env:USERNAME) {
    Write-Host "[ERROR] Cannot Disable Administrator or Current User" - ForegroundColor Red
    Write-AuditLog -Action "USER_DISABLE" -Result "FAILURE" -Details "username=$Username error=protected_account"
    return $false
}

#Disable the account

try{
    Disable-LocalUser - Name $Username
    Write-Host "[SUCCESS] Account Disabled" -ForegroundColor Green

#Update description with timestamp and optional reason
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$newDescription = "DISABLED($timestamp): $Reason"
Set-LocalUser -Name $Username -Description $newDescription

Write-AuditLog -Action "USER_DISABLE" -Result "SUCCESS" -Details "username=$Username
reason= '$Reason' "

#Display status
Write-Host "'n[SUCCESS] User '$Username' has been disabled " - ForegroundColor Green
Write-Host "Reason: $Reason " -ForegroundColor White
Write-Host ""

Get-LocalUser -Name $Username | Select-Object Name, Enabled, Description, LastLogon | Format-List

return $true
}

catch{
    Write-Host "[ERROR] Failed to Disable User: $_"- ForegroundColor Red
    Write-Auditlog -Action "USER_DISABLE" -Result "FAILURE" -Details "username=$Username 
    error=$($_.Exception.Message)"
    return $false
}
}

#************************************************************************************
#Function: Enable-LocalUserAccount
#*************************************************************************************

function Enable-LocalUserAccount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username
    )


    Write-Host "'====================================================================" -ForegroundColor Cyan
    Write-Host " Enabling User: $Username" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForgroundColor Cyan
    
#Check if user exists 
    try{
        $user = Get-LocalUser -Name $Username -ErrorAction Stop
    }
    catch{
        Write-Host "[ERROR] User '$Username' does not exist" -ForegroundColor Red
        Write-AuditLog -Action "USER_ENABLE" -Result "FAILURE" -Details "username=$Username
        error=user_not_found"
        return $false
    }

#Check if user is already enabled
if($user.Enabled){
    Write-Host "[INFO] User '$Username' is already enabled" -ForegroundColor Green
    Get-LocalUser -Name $Username | Select-Object Name, Enabled, Description, LastLogon | Format-List
    return $true
}
try{
    #Enable User Account
    Enable-LocalUser -Name $Username
    Write-Host "[SUCCESS] Account enabled" -ForegroundColor Green

        #Remove expiration if set
        if ($user.AccountExpires) {
            $expiryDate = $user.AccountExpires
            $now = Get-Date
            
            if ($expiryDate -lt $now) {
                Set-LocalUser -Name $Username -AccountExpires $null
                Write-Host "[SUCCESS] Account expiration removed" -ForegroundColor Green
            }
        }
        
        #Update description to remove "DISABLED" flag
        $currentDesc = $user.Description
        if ($currentDesc -match "DISABLED") {
            $newDesc = $currentDesc -replace "DISABLED.*?:", "RE-ENABLED $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            Set-LocalUser -Name $Username -Description $newDesc
        }
        
        Write-AuditLog -Action "USER_ENABLE" -Result "SUCCESS" -Details "username=$Username"
        
        Write-Host "`n[SUCCESS] User '$Username' has been enabled" -ForegroundColor Green
        Write-Host "The user can now login with their existing password." -ForegroundColor White
        Write-Host ""
        
        Get-LocalUser -Name $Username | Select-Object Name, Enabled, Description, AccountExpires, LastLogon | Format-List
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to enable user: $_" -ForegroundColor Red
        Write-AuditLog -Action "USER_ENABLE" -Result "FAILURE" -Details "username=$Username error=$($_.Exception.Message)"
        return $false
    }

}


#**********************************************************************************
# Main Script - Interactive Menu
#***********************************************************************************

# Check administrator
if (-not (Test-Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Main menu loop
while ($true) {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host " Windows User Creation Script v2.0" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Create single user" -ForegroundColor Yellow
    Write-Host "2. Create single user with custom groups" -ForegroundColor Yellow
    Write-Host "3. Create users from CSV file" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "USER MANAGEMENT:" -ForegroundColor Yellow
    Write-Host "4. Disable user account" -ForegroundColor White
    Write-Host "5. Enable user account" -ForegroundColor White
    Write-Host ""
    Write-Host "INFORMATION:" -ForegroundColor Yellow
    Write-Host "6. List all local users" -ForegroundColor White
    Write-Host "7. List disabled users" -ForegroundColors White
    Write-Host "8. View audit log" -ForegroundColor White
    Write-Host ""
    Write-Host "0. Exit to Main Menu" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
#Create single user
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " Create Single User" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
            $username = Read-Host "Enter username"
            $fullname = Read-Host "Enter full name"
            
            if ($username -and $fullname) {
                New-LocalUserAccount -Username $username -FullName $fullname
            } else {
                Write-Host "[ERROR] Username and full name are required" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "2" {
#Create single user with custom groups
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " Create User with Custom Groups" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
            $username = Read-Host "Enter username"
            $fullname = Read-Host "Enter full name"
            $description = Read-Host "Enter description (optional, press Enter to skip)"
            
            Write-Host "`nAvailable groups:" -ForegroundColor Cyan
            Write-Host "  - Users (default)"
            Write-Host "  - Administrators"
            Write-Host "  - Remote Desktop Users"
            Write-Host "  - Backup Operators"
            Write-Host ""
            $groupInput = Read-Host "Enter groups (comma-separated, e.g., Users,Administrators)"
            
            if ([string]::IsNullOrWhiteSpace($groupInput)) {
                $groups = @("Users")
            } else {
                $groups = $groupInput -split ',' | ForEach-Object { $_.Trim() }
            }
            
            if ($username -and $fullname) {
                if ([string]::IsNullOrWhiteSpace($description)) {
                    New-LocalUserAccount -Username $username -FullName $fullname -Groups $groups
                } else {
                    New-LocalUserAccount -Username $username -FullName $fullname -Description $description -Groups $groups
                }
            } else {
                Write-Host "[ERROR] Username and full name are required" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "3" {
#Create users from CSV
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " Bulk User Creation from CSV" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "CSV Format Required:" -ForegroundColor Yellow
            Write-Host "  username,full_name,department,role" -ForegroundColor Gray
            Write-Host "  jdoe,John Doe,IT,Administrator" -ForegroundColor Gray
            Write-Host "  jsmith,Jane Smith,HR,Manager" -ForegroundColor Gray
            Write-Host ""
            
            $csvPath = Read-Host "Enter CSV file path"
            
            if ($csvPath -and (Test-Path $csvPath)) {
                $defaultGroup = Read-Host "Enter default group (default: Users)"
                if ([string]::IsNullOrWhiteSpace($defaultGroup)) {
                    $defaultGroup = "Users"
                }
                
                Import-UsersFromCSV -CSVPath $csvPath -DefaultGroup $defaultGroup
            } else {
                Write-Host "[ERROR] CSV file not found or path not provided" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "4" {
#Disable user
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " Disable User Account" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
#Show enabled users
            Write-Host "Currently enabled users:" -ForegroundColor Yellow
            Get-LocalUser | Where-Object {$_.Enabled -eq $true -and $_.Name -ne "Administrator" -and $_.Name -ne $env:USERNAME} | ForEach-Object {
                Write-Host "  - $($_.Name)" -ForegroundColor White
            }
            Write-Host ""
            
            $username = Read-Host "Enter username to disable"
            
            if ($username) {
                $reason = Read-Host "Enter reason for disabling (optional)"
                if ([string]::IsNullOrWhiteSpace($reason)) {
                    $reason = "Account disabled by administrator"
                }
                
                $confirm = Read-Host "Disable user '$username'? (Y/N)"
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Disable-LocalUserAccount -Username $username -Reason $reason
                } else {
                    Write-Host "[INFO] Cancelled" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[ERROR] Username is required" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "5" {
#Enable user 
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " Enable User Account" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
#Show disabled users
            Write-Host "Currently disabled users:" -ForegroundColor Yellow
            $disabledUsers = Get-LocalUser | Where-Object {$_.Enabled -eq $false}
            
            if ($disabledUsers.Count -eq 0) {
                Write-Host "  No disabled users found" -ForegroundColor Green
            } else {
                $disabledUsers | ForEach-Object {
                    Write-Host "  - $($_.Name)" -ForegroundColor White
                }
            }
            Write-Host ""
            
            $username = Read-Host "Enter username to enable"
            
            if ($username) {
                $confirm = Read-Host "Enable user '$username'? (Y/N)"
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Enable-LocalUserAccount -Username $username
                } else {
                    Write-Host "[INFO] Cancelled" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[ERROR] Username is required" -ForegroundColor Red
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "6" {
 #List all users
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " All Local Users" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
            $users = Get-LocalUser | Sort-Object Name
            
            foreach ($user in $users) {
                $status = if ($user.Enabled) { "Enabled" } else { "Disabled" }
                $color = if ($user.Enabled) { "Green" } else { "Red" }
                
                Write-Host "User: $($user.Name)" -ForegroundColor White
                Write-Host "  Full Name: $($user.FullName)" -ForegroundColor Gray
                Write-Host "  Status: $status" -ForegroundColor $color
                Write-Host "  Last Logon: $($user.LastLogon)" -ForegroundColor Gray
                Write-Host ""
            }
            
            Write-Host "Total users: $($users.Count)" -ForegroundColor Cyan
            Write-Host "Enabled: $(($users | Where-Object {$_.Enabled}).Count)" -ForegroundColor Green
            Write-Host "Disabled: $(($users | Where-Object {-not $_.Enabled}).Count)" -ForegroundColor Red
            
            Read-Host "`nPress Enter to continue"
        }
        "7" {
#List disabled users (NEW)
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " Disabled Users" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
            $disabledUsers = Get-LocalUser | Where-Object {$_.Enabled -eq $false} | Sort-Object Name
            
            if ($disabledUsers.Count -eq 0) {
                Write-Host "No disabled users found" -ForegroundColor Green
            } else {
                foreach ($user in $disabledUsers) {
                    Write-Host "User: $($user.Name)" -ForegroundColor Red
                    Write-Host "  Full Name: $($user.FullName)" -ForegroundColor Gray
                    Write-Host "  Description: $($user.Description)" -ForegroundColor Gray
                    Write-Host "  Last Logon: $($user.LastLogon)" -ForegroundColor Gray
                    Write-Host ""
                }
                
                Write-Host "Total disabled users: $($disabledUsers.Count)" -ForegroundColor Cyan
            }
            
            Read-Host "`nPress Enter to continue"
        }
        "8" {
#View audit log
            Clear-Host
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host " Audit Log (Last 20 entries)" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            
            if (Test-Path $AuditLog) {
                Get-Content $AuditLog -Tail 20 | ForEach-Object {
                    if ($_ -match "SUCCESS") {
                        Write-Host $_ -ForegroundColor Green
                    } elseif ($_ -match "FAILURE") {
                        Write-Host $_ -ForegroundColor Red
                    } else {
                        Write-Host $_ -ForegroundColor White
                    }
                }
            } else {
                Write-Host "[INFO] No audit log found yet" -ForegroundColor Yellow
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