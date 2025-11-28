# SysAdmin Toolkit - Crossplatform

> A comprehensive cross-platform system administration automation toolkit.

![Version](https://img.shields.io/badge/version-1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey)

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Project Relevance](#project-relevance)
- [Methodology](#3-methodology)
- [Results](#results)
- [Conclusion](#conclusion)
- [Quick Start](#quick-start)
- [Author](#author)
---

<a name="project-overview"></a>
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
- Used Faker library to generate realistic user data for bulk creation testing (50+ users with randomized names, departments, roles)
- Created dummy files and directories to simulate production backup scenarios (161 MB test dataset with 112 files)
- Structured test data to reflect real-world usage patterns (nested directories, various file types, mixed file sizes)

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

#### Universal Launcher Menu

<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/285035ea-4482-41d2-b426-958e16248309" /><img width="400" height="382" alt="image" src="https://github.com/user-attachments/assets/07c034a6-ca96-4e7e-ba22-201760ae1655" />

#### User Creation
<img width="400" height="286" alt="image" src="https://github.com/user-attachments/assets/271a6653-2b68-440d-aaa5-4a1077babfe1" /><img width="400" height="900" alt="image" src="https://github.com/user-attachments/assets/02e04f06-06e1-4551-b1e2-cef4463776ab" />

#### System Monitoring
<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/6c389234-eb8f-4da6-bd90-3ee9847fda4c" /><img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/d46d3401-4a7d-47e2-bef0-807fb86a1b33" />

#### Backup Operations
<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/9744dbe2-9726-4cee-9594-07b9fe919013" /><img width="400" height="380" alt="image" src="https://github.com/user-attachments/assets/b433a726-94a2-42cb-9ff7-86ae5a9a95de" />


#### Audit Log
<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/98e4eddc-9691-44ad-8338-1de8532ca047" /><img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/97956c7f-fdd1-4bbb-9ba2-484b52d8edb8" />

#### Service Management

<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/b2ad13a5-a0a6-491c-a6c0-37391287fc32" /><img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/ea5a87a0-33e0-4c9b-ad95-b58887077675" />

### Compression & Storage Efficiency

**Test: C:\TestBackup directory backup**
- Original size: 161.45 MB
- Compressed size: 57.51 KB
- Compression ratio: 99.96%
- Files backed up: 112 files
- Storage savings: ~161 MB per backup

---

## 🎓 Conclusion

### Summary

This project successfully delivers a production-ready automation toolkit that:
- **Eliminates manual errors** through Consistent, Automated Processes
- **Enforces security policies** (Strong Passwords, Expiration, Audit Trails)
- **Provides cross-platform support** via Unified Launcher
- **Generates compliance-ready logs** for Forensic Investigation

### Lessons Learned

**Technical:**
- Cross-platform tools require careful planning, including OS detection and platform-specific modules.
- Strong error handling and clear messages are essential for reliability.
- Security must be built in from the start—password strength, least privilege, and audit logging are non-negotiable.
- Git Bash provides an easy way to run Bash scripts on Windows without WSL.

**Operational:**
- Automated configuration management reduces human error and keeps systems consistent.
- Detailed audit logs support compliance and forensic investigations.
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

