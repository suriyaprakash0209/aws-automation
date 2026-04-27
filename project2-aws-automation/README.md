# ☁️ AWS Server Automation — Health Monitor + S3 Backup System

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![AWS S3](https://img.shields.io/badge/AWS%20S3-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![AWS IAM](https://img.shields.io/badge/AWS%20IAM-DD344C?style=for-the-badge&logo=amazonaws&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Cron](https://img.shields.io/badge/Cron-Jobs-00BFFF?style=for-the-badge)

## 📌 Project Overview

A **fully automated Linux server operations system** that runs without any human intervention:

- 🔍 **Health Monitor** — checks CPU, memory, disk every 30 minutes and alerts on thresholds
- ☁️ **S3 Backup** — compresses logs and uploads to AWS S3 every night at 2 AM
- 🧹 **Retention Policy** — automatically deletes backups older than 30 days
- 🔐 **IAM Least-Privilege** — IAM policy grants only the exact S3 permissions required

This project directly reflects a DevOps mindset: **automate repetitive tasks, reduce human error, and ensure nothing is missed.**

---

## 🏗️ Architecture

```
Linux Server (EC2 / Any Ubuntu Server)
│
├── Cron Scheduler
│   ├── Every 30 min ──► server_health_monitor.sh
│   │                        ├── Check CPU usage
│   │                        ├── Check Memory usage
│   │                        ├── Check Disk usage
│   │                        ├── Log results to /logs/
│   │                        └── Alert if thresholds exceeded
│   │
│   ├── Daily 2:00 AM ──► s3_backup.sh
│   │                        ├── Compress /logs/ → .tar.gz
│   │                        ├── Upload → s3://bucket/backups/YYYY-MM-DD/
│   │                        ├── Verify upload
│   │                        └── Delete local temp file
│   │
│   └── Weekly Sunday ──► Log cleanup (remove 30+ day old logs)
│
└── AWS S3 Bucket
    └── backups/
        ├── 2025-01-01/server_backup_2025-01-01_02-00-00.tar.gz
        ├── 2025-01-02/server_backup_2025-01-02_02-00-00.tar.gz
        └── ...
```

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| Bash | Scripting and automation |
| Linux / Ubuntu | Server OS |
| Cron | Job scheduling |
| AWS S3 | Cloud backup storage |
| AWS IAM | Least-privilege access control |
| AWS CLI | Interface to AWS services |

---

## 📁 Project Structure

```
project2-aws-automation/
├── scripts/
│   ├── server_health_monitor.sh   # CPU/Memory/Disk health checks
│   ├── s3_backup.sh               # Compress and upload to S3
│   └── setup_cron.sh              # One-time cron installation
├── docs/
│   └── iam_policy.json            # Least-privilege IAM policy
├── logs/                          # Auto-created, git-ignored
├── .gitignore
└── README.md
```

---

## 🚀 How to Set Up

### Step 1 — AWS Prerequisites

**Create an S3 bucket:**
```bash
aws s3 mb s3://your-backup-bucket-name --region ap-south-1
```

**Create an IAM user with the policy in `docs/iam_policy.json`:**
```bash
# Create user
aws iam create-user --user-name devops-backup-user

# Attach the policy (after creating it in console or CLI)
aws iam put-user-policy \
  --user-name devops-backup-user \
  --policy-name S3BackupPolicy \
  --policy-document file://docs/iam_policy.json
```

**Configure AWS CLI on your server:**
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (ap-south-1), Output (json)
```

### Step 2 — Clone and Configure

```bash
git clone https://github.com/YOUR_USERNAME/aws-server-automation.git
cd aws-server-automation

# Edit s3_backup.sh — update these two lines:
S3_BUCKET="your-actual-bucket-name"
AWS_REGION="ap-south-1"   # or your region
```

### Step 3 — Install Cron Jobs (One Command)

```bash
chmod +x scripts/setup_cron.sh
./scripts/setup_cron.sh
```

That's it. Full automation is now running.

---

## 🧪 Manual Testing

```bash
# Test health monitor
chmod +x scripts/server_health_monitor.sh
./scripts/server_health_monitor.sh

# Test S3 backup
chmod +x scripts/s3_backup.sh
./scripts/s3_backup.sh

# Check installed cron jobs
crontab -l

# Watch logs live
tail -f logs/cron.log
```

---

## 📊 Sample Health Monitor Output

```
═══════════════════════════════════════════════════
   SERVER HEALTH MONITOR — ip-172-31-42-10
   2025-01-15 14:30:00
═══════════════════════════════════════════════════

  CPU Usage:    23% ✅ NORMAL
  Memory:       61% ✅ NORMAL
  Details:      Total: 7.7G | Used: 4.7G | Free: 2.1G
  Disk (root):  34% ✅ NORMAL
  Details:      Total: 29G | Used: 9.7G | Available: 19G
  Load Avg:     0.12, 0.08, 0.05

  Top CPU Processes:
    ubuntu          0.5%    /usr/bin/python3
    root            0.2%    /usr/sbin/sshd
    ubuntu          0.1%    bash

  Service Status:
    ✅ ssh: running
    ✅ docker: running
    ❌ nginx: not running (or not installed)
    ✅ cron: running

  Server Uptime: up 3 days, 2 hours, 14 minutes
═══════════════════════════════════════════════════
```

---

## 🔐 Security Design

- IAM policy uses **least-privilege** — only grants `PutObject`, `GetObject`, `ListBucket`, `DeleteObject` on the specific backup bucket
- No hardcoded AWS credentials in scripts — uses `aws configure` or EC2 IAM Role
- Log files are **git-ignored** — no sensitive data committed
- Scripts use `set -euo pipefail` — fail fast on any error

---

## ⚙️ Alert Thresholds (Configurable)

| Metric | Alert Threshold | Location |
|--------|----------------|----------|
| CPU | 80% | `server_health_monitor.sh` line 14 |
| Memory | 85% | `server_health_monitor.sh` line 15 |
| Disk | 90% | `server_health_monitor.sh` line 16 |
| Backup retention | 30 days | `s3_backup.sh` line 17 |

---

## 💡 Key Learnings

- Cron eliminates manual repetitive tasks entirely — set once, runs forever
- Compression before upload reduces S3 storage costs significantly
- Automated retention policies prevent storage accumulation without human oversight
- Least-privilege IAM ensures the backup script can't accidentally delete other AWS resources

---

## 👤 Author

**Suriya Prakash Jagan** — Junior DevOps Engineer  
[LinkedIn](https://www.linkedin.com/in/suriya-prakash-jagan-5594aa263) | Chennai, India
