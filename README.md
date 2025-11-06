# SysAdmin Toolkit - Universal Edition

> A comprehensive cross-platform system administration automation toolkit.

![Version](https://img.shields.io/badge/version-1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey)

## 🎯 Overview

The SysAdmin Toolkit is an automation suite I built for managing both Linux and Windows systems. It includes 10 essential tools, all organized under one easy-to-use, cross-platform launcher to help streamline system administration tasks.

**Key Features:**
- ✅ Universal bash launcher with automatic OS detection
- ✅ 5 Linux automation scripts (Bash)
- ✅ 5 Windows automation scripts (PowerShell)
- ✅ Comprehensive audit logging
- ✅ Menu-driven interface


## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Features](#-features)
- [Linux Tools](#linux-tools)
- [Windows Tools](#windows-tools)
- [Installation](#-installation)
- [Project Structure](#-project-structure)
- [Requirements](#-requirements)
- [Testing](#-testing)
- [Author](#-author)

## 🚀 Quick Start

### On Linux:
```bash
git clone https://github.com/yourusername/sysadmin-toolkit.git
cd sysadmin-toolkit
chmod +x sysadmin-toolkit.sh
sudo ./sysadmin-toolkit.sh
```

### On Windows (Git Bash):
```bash
git clone https://github.com/yourusername/sysadmin-toolkit.git
cd sysadmin-toolkit
./sysadmin-toolkit.sh
```

## ✨ Features

### Universal Launcher

### Linux Tools 

#### 1. User Management (`create_user.sh`)
- Create individual user accounts with security policies
- Bulk import from CSV files
- Automatic password generation (16-character secure passwords)
- Group management and permissions
- Password expiration policies (90 days)
- Account expiration (1 year)
- Audit logging

**Example:**
```bash
sudo ./bin/linux/create_user.sh -u jdoe -f "John Doe"
```

#### 2. Backup Automation (`backup_files.sh`)
- Compress directories to tar.gz archives
- Timestamp-based naming (YYYYMMDD_HHMMSS)
- Automatic Rotation (7-day retention by default)
- Disk space validation
- 90%+ compression ratios

**Example:**
```bash
sudo ./bin/linux/backup_files.sh -s /home -d /backup
```

#### 3. Log Rotation (`rotate_logs.sh`)
- Compress logs older than 7 days (gzip)
- Delete logs older than 30 days
- Size-based rotation (>50MB threshold)
- Statistics and reporting

**Example:**
```bash
sudo ./bin/linux/rotate_logs.sh
```

#### 4. System Monitoring (`monitor_system.sh`)
- CPU usage monitoring (configurable threshold)
- Memory usage tracking
- Disk space alerts
- Load average checking

**Example:**
```bash
sudo ./bin/linux/monitor_system.sh --cpu-threshold 80
```

#### 5. Service Management (`manage_service.sh`)
- Start/stop/restart any systemd service
- Enable/disable services at boot
- Check service status and dependencies
- View service logs (journalctl integration)

**Example:**
```bash
sudo ./bin/linux/manage_service.sh restart nginx
```

### Windows Tools

#### 1. User Management (`New-BulkUsers.ps1`)
- Create local user accounts
- Bulk import from CSV files
- Secure password generation
- Group membership management
- Password policies (change on first login)
- Audit logging to C:\Logs

**Example:**
```powershell
. .\bin\windows\New-BulkUsers.ps1
New-LocalUserAccount -Username "jdoe" -FullName "John Doe"
```

#### 2. Backup Automation (`Backup-Files.ps1`)
- ZIP compression for directories
- Automatic rotation (7-day retention)
- Timestamp-based naming
- Disk space checking
- 90%+ compression ratios

**Example:**
```powershell
. .\bin\windows\Backup-Files.ps1
```

#### 3. Event Log Management (`Manage-EventLogs.ps1`)
- Archive event logs to .evtx files
- Clear logs safely (with archive)
- Event summaries (errors, warnings, info)
- Old archive cleanup (30-day retention)
- Source identification

**Example:**
```powershell
. .\bin\windows\Manage-EventLogs.ps1
```

#### 4. System Monitoring (`Monitor-System.ps1`)
- CPU usage monitoring
- Memory usage tracking (GB and %)
- Disk space alerts for all drives
- Top 5 process identification
- Alert logging

**Example:**
```powershell
. .\bin\windows\Monitor-System.ps1
```

#### 5. Service Management (`Manage-Service.ps1`)
- Start/stop/restart Windows services
- Change startup type (Automatic/Manual/Disabled)
- Service status and dependencies
- Process ID and path information

**Example:**
```powershell
. .\bin\windows\Manage-Service.ps1
Restart-ServiceSafe -ServiceName "Spooler"
```

## 📦 Installation

### Prerequisites

**Linux:**
- Ubuntu 20.04+ or equivalent
- Bash 4.0+
- Root/sudo access

**Windows:**
- Windows Server 2019+ or Windows 10/11
- PowerShell 5.1+
- Git Bash (for universal launcher)
- Administrator privileges

### Clone Repository
```bash
git clone https://github.com/yourusername/sysadmin-toolkit.git
cd sysadmin-toolkit
```

### Make Scripts Executable (Linux)
```bash
chmod +x sysadmin-toolkit.sh
chmod +x bin/linux/*.sh
```

### Set PowerShell Execution Policy (Windows)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 💻 Usage

### Method 1: Universal Launcher (Recommended)
```bash
./sysadmin-toolkit.sh
```

**Features:**
- Automatic OS detection
- Menu-driven interface
- Built-in help and documentation

### Method 2: Direct Script Execution

**Linux:**
```bash
sudo ./bin/linux/create_user.sh -u username -f "Full Name"
```

**Windows:**
```powershell
. .\bin\windows\New-BulkUsers.ps1
New-LocalUserAccount -Username "username" -FullName "Full Name"
```

## 📁 Project Structure
```
sysadmin-toolkit/
├── sysadmin-toolkit.sh          # Universal launcher
├── README.md                     # This file
├── DEMO.md                       # Usage scenarios
├── bin/
│   ├── linux/                    # Linux automation scripts
│   │   ├── create_user.sh
│   │   ├── create_users_from_csv.sh
│   │   ├── backup_files.sh
│   │   ├── rotate_logs.sh
│   │   ├── monitor_system.sh
│   │   └── manage_service.sh
│   └── windows/                  # Windows automation scripts
│       ├── New-BulkUsers.ps1
│       ├── Backup-Files.ps1
│       ├── Manage-EventLogs.ps1
│       ├── Monitor-System.ps1
│       └── Manage-Service.ps1
├── lib/
│   └── common.sh                 # Shared functions (Linux)
├── data/
│   └── test_users.csv            # Sample user data
└── docs/
    └── examples/                 # Sample outputs
```

## 🔧 Requirements

### Linux
- Operating System: Ubuntu 20.04+
- Shell: Bash 4.0+
- Utilities: tar, gzip, systemctl, useradd, df, top
- Permissions: root/sudo access

### Windows
- Operating System: Windows Server 2019+, Windows 10/11
- PowerShell: Version 5.1 or higher
- .NET Framework: 4.5+
- Permissions: Administrator access
- Optional: Git Bash (for universal launcher)

## 🧪 Testing

### Test Environment
- **Linux VM:** Ubuntu 24.04 LTS (VirtualBox)
- **Windows VM:** Windows Server 2022 Standard Evaluation (VirtualBox)

### Tested Scenarios
- ✅ User creation (50+ users from CSV on both platforms)
- ✅ Backup creation and rotation
- ✅ Log rotation and cleanup
- ✅ System monitoring with alerts
- ✅ Service management (start/stop/restart)
- ✅ Cross-platform launcher functionality


### Audit Logging

**Linux:** `/var/log/sysadmin-toolkit/audit.log`
**Windows:** `C:\Logs\SysAdminToolkit\audit.log`

Format: `[YYYY-MM-DD HH:MM:SS] ACTION:action_name RESULT:status DETAILS:info`

## 👤 Author

**Cyril Thomas**
- Project: System Administration Automation Toolkit
- Date: November 2025
- Purpose: Capstone Project - System Administration & Security

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

