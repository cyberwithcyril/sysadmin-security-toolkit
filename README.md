# SysAdmin Toolkit - Crossplatform

> A comprehensive cross-platform system administration automation toolkit.

![Version](https://img.shields.io/badge/version-1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey)

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Project Relevance](#-project-relevance)
- [Methodology](#-methodology)
- [Results](#-results)
- [Conclusion](#-conclusion)
- [Quick Start](#-quick-start)
- [Requirements](#-requirements)
- [Author](#-author)
---

## 🎯 1. Project Overview

### Summary

The **SysAdmin Toolkit** is a cross-platform automation suite built to simplify everyday
system administration tasks while promoting strong security practices in mixed enterprise environments. It includes 10 production-ready scripts -five for Linux and five for Windows
-that automate essential functions like User Management, Backups, Log Handling, System
Monitoring, and Service Control

### Objectives

**Primary Goal:** Reduce the amount of manual system administration work while strengthening the organization’s security posture through consistent, auditable automation.

**Key Objectives:**
1. Automate repetitive tasks and eliminate human error
2. Provide unified tooling for mixed Linux/Windows environments
3. Enforce security standards (password policies, audit logging)
4. Generate compliance-ready audit trails
5. Improve operational efficiency

### Capabilities

The toolkit includes 10 essential tools organized under one unified, cross-platform launcher:

**Linux Tools:**
- User Management (Single/Bulk creation with Security Policies)
- Backup Automation (Compression, Rotation, Space Validation)
- Log Rotation (Compression, Cleanup, Size Management)
- System Monitoring (CPU, Memory, Disk Alerts)
- Service Management (Systemd Service Control)

**Windows Tools:**
- User Management (Local Account Creation with Policies)
- Backup Automation (ZIP compression with Rotation)
- Event Log Management (Archival and Cleanup)
- System Monitoring (Resource Tracking and Alerting)
- Service Management (Windows Service Control)

**Universal Features:**
- Single launcher script with automatic OS detection

---

## 🔍 2. Project Relevance

### Why This Matters in Cybersecurity & Forensics

Manual system administration is prone to errors—weak passwords, forgotten accounts, and inconsistent configurations all create openings for attackers. Misconfiguration and human error remain two of the biggest contributors to modern security incidents.

### Problems Addressed:
**Attack Surface Reduction**
- Enforces 16-character password complexity automatically
- Implements account expiration (90-day passwords, 1-year accounts)
- Provides complete audit trails for forensic investigation

**Incident Response**
- Automated backups with 7-day rotation for point-in-time recovery
- High compression ratios reduce storage costs
- Validation ensures backup integrity

**Security Operations**
- Real-time resource monitoring with configurable thresholds
- Automated alerting for anomalies
- Log aggregation for SIEM integration

---
## ⚙️ 3. Methodology

### Development Environment

**Testing Infrastructure:**
- Linux VM: Ubuntu 24.04 LTS (VirtualBox, 4GB RAM, 2 cores)
- Windows VM: Windows Server 2022 (VirtualBox, 4GB RAM, 2 cores)
- Isolated networks for safe testing

**Tools:**
- Visual Studio Code (PowerShell + Bash extensions)
- Git/GitHub for version control
- VirtualBox for VM isolation

### Architecture
```
┌────────────────────────────────────────┐
│     UNIVERSAL LAUNCHER                 │
│   (sysadmin-toolkit.sh)                │
│                                         │
│  OS Detection (uname -s)               │
│  • Linux   → /bin/linux/*.sh           │
│  • Windows → /bin/windows/*.ps1        │
└──────────────┬─────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
   Linux Scripts    Windows Scripts
   (Bash .sh)       (PowerShell .ps1)
       │                │
       └────┬───────────┘
            │
    ┌───────▼────────┐
    │ Audit Logging  │
    │ Linux:  /var/log/sysadmin-toolkit/
    │ Windows: C:\Logs\SysAdminToolkit/  │
    └────────────────┘
```
### Data Flow Example (User Creation)
```
User Input (CSV or CLI)
    │
    ├──> Input Validation (format, duplicates, permissions)
    │
    ├──> Password Generation (16-char secure random)
    │
    ├──> Account Creation (useradd/New-LocalUser)
    │
    ├──> Security Policies (90-day password, 1-year account expiration)
    │
    └──> Audit Logging ([TIMESTAMP] ACTION:create_user RESULT:success)
```

### Development Process

**Phase 1: Planning**
- Identified common sysadmin pain points through research
- Prioritized portability and security-first design

**Phase 2: Core Development**
- Built 5 Linux scripts (Bash) with security controls
- Built 5 Windows scripts (PowerShell) with equivalent functionality
- Implemented password generation, audit logging, error handling

**Phase 3: Integration**
- Created universal launcher with OS detection
- Integrated Git Bash for Windows compatibility
- Built menu-driven interface

**Phase 4: Testing**
- Unit testing with valid/invalid inputs
- Security testing (password strength, input sanitization)
- Fresh VM deployment validation

**Phase 5: Documentation**
- Comprehensive README and inline comments
- Usage examples and help messages

---
## 📊 Results

### Functional Verification

**Tested Scenarios:**
- ✅ Bulk user creation (50+ users from CSV)
- ✅ Automated backups with rotation (7-day retention)
- ✅ Log compression and cleanup
- ✅ Real-time system monitoring with alerts
- ✅ Service management (start/stop/restart)
- ✅ Cross-platform launcher on both OSes

### Security Validation

**Password Policy Enforcement:**
```
Automation (Toolkit):
- 100% compliance with 16-char minimum
- 100% have 90-day password expiration
- 100% have 1-year account expiration
- 100% audit logging of all actions
```

### Sample Audit Log Output
```
[2024-11-25 14:23:45] ACTION:create_user RESULT:success DETAILS:username=jdoe
[2024-11-25 14:30:12] ACTION:backup RESULT:success DETAILS:source=/home,size=1.16GB
[2024-11-25 15:45:33] ACTION:monitor_alert RESULT:warning DETAILS:cpu_usage=85%
[2024-11-25 16:10:22] ACTION:service_restart RESULT:success DETAILS:service=nginx
```

### Screenshots & Evidence

**Universal Launcher Menu**
<img width="816" height="730" alt="image" src="https://github.com/user-attachments/assets/fd7d3452-937d-40fb-b6dd-3b31cb8ad9d8" />

**User Creation**
<img width="869" height="705" alt="image" src="https://github.com/user-attachments/assets/704bc132-dffd-403d-83b1-ef7096d7930c" />


**[Screenshot Area 3: System Monitoring Alert]**
*Add screenshot of system monitor detecting high CPU usage and displaying alert*

**[Screenshot Area 4: Backup Operation]**
*Add screenshot showing backup progress and compression statistics*

**[Screenshot Area 5: Audit Log Output]**
*Add screenshot of audit log file showing timestamped actions*

### Compression & Storage Efficiency

**Test: 15GB /home directory backup**
- Original size: 15.0 GB
- Compressed size: 1.16 GB
- Compression ratio: 92.3%
- Storage savings: ~14GB per backup

---

## 🎓 Conclusion

### Summary

This project successfully delivers a production-ready automation toolkit that:
- **Eliminates manual errors** through consistent, automated processes
- **Enforces security policies** (strong passwords, expiration, audit trails)
- **Provides cross-platform support** via unified launcher
- **Generates compliance-ready logs** for forensic investigation

### Lessons Learned

**Technical:**
- Cross-platform development requires strategic abstraction and OS detection
- Error handling must be comprehensive—validate inputs before execution
- Security controls must be built-in from the start (passwords, permissions, logging)
- Git Bash enables true cross-platform Bash scripts on Windows

**Operational:**
- Automation consistency eliminates configuration drift
- Audit logging is essential for compliance and forensics
- User-friendly interfaces (help messages, color output) drive adoption

### Next Steps

1. **Web Dashboard** - React frontend with real-time monitoring visualization and task scheduling
2. **Cloud Integration** - Extend toolkit to AWS/Azure for hybrid environment management
3. **Compliance Automation** - Add CIS Benchmark scanning and STIG remediation scripts

---

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


  
## 👤 Author

**Cyril Thomas**
- Project: System Administration Automation Toolkit
- Date: November 2025
- Purpose: Capstone Project - System Administration & Security

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

