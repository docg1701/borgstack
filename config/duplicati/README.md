# Duplicati Backup Configuration

This directory contains configuration and documentation for the Duplicati automated backup system.

## Overview

Duplicati provides encrypted, automated backups of all BorgStack data to external storage destinations. All backup data is encrypted with AES-256 **before** upload, ensuring data security regardless of storage provider.

**Version:** Duplicati 2.1.1.102

## Backup Strategy

### Incremental Backups

Duplicati uses intelligent incremental backups:
- **First backup**: Full backup of all data sources
- **Subsequent backups**: Only changed files and data blocks are backed up
- **Deduplication**: Identical data blocks are stored only once (reduces storage costs)
- **Compression**: zstd compression for optimal speed/ratio balance

### Retention Policy (Recommended)

- **7 daily backups**: Keep last 7 days of daily backups
- **4 weekly backups**: Keep last 4 weeks of weekly backups
- **12 monthly backups**: Keep last 12 months of monthly backups

**Total storage estimate**: Approximately 2-3x your current data size (varies by change rate)

### Backup Schedule (Recommended)

- **Daily backups**: 2:00 AM BRT (America/Sao_Paulo timezone)
- **Timing**: Scheduled during low-traffic hours to minimize performance impact

## Backup Sources

Duplicati backs up the following critical data volumes:

### Database Backups

| Source | Mount Point | Contents | Priority |
|--------|-------------|----------|----------|
| PostgreSQL | `/source/postgresql` | n8n_db, chatwoot_db, directus_db, evolution_db | **CRITICAL** |
| MongoDB | `/source/mongodb` | Lowcoder database | **CRITICAL** |
| Redis | `/source/redis` | RDB snapshots, AOF files | **HIGH** |

### Object Storage Backups

| Source | Mount Point | Contents | Priority |
|--------|-------------|----------|----------|
| SeaweedFS Master | `/source/seaweedfs_master` | Volume topology, cluster metadata | **CRITICAL** |
| SeaweedFS Volume | `/source/seaweedfs_volume` | Actual file content (largest volume) | **CRITICAL** |
| SeaweedFS Filer | `/source/seaweedfs_filer` | Directory structure, S3 path mapping | **CRITICAL** |

### Application Data Backups

| Source | Mount Point | Contents | Priority |
|--------|-------------|----------|----------|
| n8n | `/source/n8n` | Workflows, encrypted credentials | **CRITICAL** |
| Evolution API | `/source/evolution` | WhatsApp sessions, QR codes | **CRITICAL** |
| Chatwoot Storage | `/source/chatwoot_storage` | File uploads, attachments | **HIGH** |
| Lowcoder Stacks | `/source/lowcoder_stacks` | Application definitions | **HIGH** |
| Directus Uploads | `/source/directus_uploads` | CMS media files | **HIGH** |
| FileFlows Data | `/source/fileflows_data` | Flow definitions, configurations | **MEDIUM** |
| FileFlows Logs | `/source/fileflows_logs` | Processing history | **LOW** |
| FileFlows Input | `/source/fileflows_input` | Media awaiting processing | **MEDIUM** |
| FileFlows Output | `/source/fileflows_output` | Processed media files | **MEDIUM** |
| Caddy Data | `/source/caddy` | SSL certificates, ACME data | **HIGH** |

**Note**: All volumes are mounted **read-only** (`:ro` flag) in the Duplicati container for safety.

## Supported Backup Destinations

Duplicati supports multiple backup destinations. Choose based on your needs:

### Cloud Storage (Recommended for Production)

#### AWS S3 / S3-Compatible

**Best for**: Brazilian customers requiring data sovereignty
**Recommendation**: AWS S3 São Paulo region (sa-east-1)

- **Endpoint**: `https://s3.sa-east-1.amazonaws.com` (São Paulo)
- **Authentication**: AWS Access Key ID + Secret Access Key
- **Pricing**: ~$0.023/GB/month (sa-east-1 region)
- **Data location**: Brazil (LGPD compliant)

**Configuration**:
- Storage Type: S3 Compatible
- Server: `s3.sa-east-1.amazonaws.com`
- Bucket: `borgstack-backups-{customer-name}`
- AWS Access Key ID: From AWS IAM
- AWS Secret Access Key: From AWS IAM

#### Backblaze B2 (Cost-Effective Alternative)

**Best for**: Cost-conscious deployments, privacy-focused customers

- **Endpoint**: `https://api.backblazeb2.com`
- **Authentication**: Application Key ID + Application Key
- **Pricing**: ~$0.005/GB/month (70% cheaper than AWS S3)
- **Data location**: US/EU data centers (select region during bucket creation)
- **Free tier**: 10GB storage + 1GB daily download

**Configuration**:
- Storage Type: B2 Cloud Storage
- Account ID: From Backblaze B2 console
- Application Key: From Backblaze B2 console
- Bucket: `borgstack-backups-{customer-name}`

#### Google Cloud Storage

**Best for**: Customers already using Google Cloud Platform

- **Endpoint**: `https://storage.googleapis.com`
- **Authentication**: Service Account JSON key
- **Pricing**: ~$0.020/GB/month (Southamerica-east1 - São Paulo)
- **Data location**: Brazil or multi-region

#### Azure Blob Storage

**Best for**: Customers using Microsoft Azure ecosystem

- **Endpoint**: `https://{account}.blob.core.windows.net`
- **Authentication**: Storage Account Name + Access Key
- **Pricing**: ~$0.018/GB/month (Brazil South region)

### On-Premises / Self-Hosted

#### FTP/SFTP Servers

**Best for**: Existing NAS infrastructure, air-gapped backups

- **Authentication**: Username + Password (FTP) or SSH key (SFTP)
- **Encryption**: Use SFTP (SSH) for secure transport
- **Note**: Duplicati still encrypts data before upload (defense in depth)

**Configuration**:
- Server: `ftp.example.com` or `sftp.example.com`
- Port: 21 (FTP) or 22 (SFTP)
- Path: `/backups/borgstack/`
- Username: FTP/SFTP user
- Password/Key: Authentication credentials

#### WebDAV (Nextcloud, ownCloud)

**Best for**: Self-hosted cloud storage, privacy-focused deployments

- **Endpoint**: `https://cloud.example.com/remote.php/dav/files/USERNAME/`
- **Authentication**: WebDAV username + app password
- **Encryption**: HTTPS transport + Duplicati AES-256 encryption

**Configuration**:
- Server: `https://cloud.example.com/remote.php/dav/files/USERNAME/`
- Path: `/BorgStack-Backups/`
- Username: Nextcloud/ownCloud username
- Password: App password (not main password)

#### Local / Network Drives

**Best for**: Quick local backups, backup-to-backup strategies

- **Path**: `/mnt/backup-drive/` or `/mnt/nas/borgstack-backups/`
- **Authentication**: File system permissions
- **Note**: Ensure mount point is available before backup starts

**Configuration**:
- Storage Type: Local folder or mapped network drive
- Path: Absolute path to backup destination
- Note: Mount network drives in `docker-compose.yml` volumes section

## Initial Setup Instructions

### 1. Access Duplicati Web UI

Navigate to: `https://duplicati.{BORGSTACK_DOMAIN}`

Login with the password from `.env` file (`DUPLICATI_PASSWORD`)

### 2. Create Backup Job

1. Click **"Add backup"**
2. **General settings**:
   - Name: `BorgStack-Full-Backup`
   - Description: `Automated backup of all BorgStack data`
   - Encryption: **AES-256 encryption, built-in**
   - Passphrase: **Use `DUPLICATI_PASSPHRASE` from .env file**
   - ⚠️ **CRITICAL**: Store passphrase securely - without it, backups cannot be restored!

3. **Backup destination**:
   - Choose your destination type (see "Supported Backup Destinations" above)
   - Enter credentials and bucket/path information
   - Click **"Test connection"** to verify

4. **Source data**:
   - Click **"Source Data"** tab
   - Select **all** source directories:
     - `/source/postgresql`
     - `/source/mongodb`
     - `/source/redis`
     - `/source/seaweedfs_master`
     - `/source/seaweedfs_volume`
     - `/source/seaweedfs_filer`
     - `/source/n8n`
     - `/source/evolution`
     - `/source/chatwoot_storage`
     - `/source/lowcoder_stacks`
     - `/source/directus_uploads`
     - `/source/fileflows_data`
     - `/source/fileflows_logs`
     - `/source/fileflows_input`
     - `/source/fileflows_output`
     - `/source/caddy`

5. **Schedule**:
   - Run backup: **Automatically**
   - Repeat: **Daily at 2:00 AM** (adjust timezone to America/Sao_Paulo)
   - Days to keep backups: Use retention policy settings below

6. **Options** (Advanced):
   - **Compression**: zstd (optimal balance)
   - **Backup retention**:
     - Keep all backups newer than: `7D` (7 days)
     - Smart retention: `7D:1D,4W:1W,12M:1M` (7 daily, 4 weekly, 12 monthly)
   - **Upload volume size**: `50MB` (smaller chunks for resume capability)
   - **Keep versions**: `1` (keep 1 version of deleted files)

7. Click **"Save"** to create backup job

### 3. Run First Backup (Test)

1. Select the backup job you created
2. Click **"Run now"**
3. Monitor progress in the web UI
4. **First backup will be FULL** (may take several hours depending on data size)
5. Verify backup completed successfully

### 4. Test Restoration (Critical!)

**After first successful backup**, test restoration:

1. Select backup job
2. Click **"Restore"**
3. Choose a recent backup version
4. Select a small test file (e.g., from `/source/caddy`)
5. Restore to: `/tmp/restore-test/`
6. Click **"Restore"**
7. Verify file was restored successfully
8. Delete test restoration: `rm -rf /tmp/restore-test/`

**Do NOT skip this step!** Testing restoration ensures you can recover data when needed.

## Backup Verification

### Automatic Verification

Configure Duplicati to verify backups automatically:

1. Edit backup job
2. Go to **Options** → **Advanced**
3. Enable **"Run verification after backup"**
4. Frequency: Every backup (or every 7 days for faster backups)

### Manual Verification

To manually verify backup integrity:

1. Select backup job
2. Click **"Verify files"**
3. Choose verification level:
   - **Download file lists**: Fast, verifies metadata only
   - **Download and verify files**: Slow, verifies actual data
4. Click **"Verify"**

## Brazilian Data Sovereignty Considerations

For customers subject to LGPD (Lei Geral de Proteção de Dados):

### Recommended Backup Destinations

1. **AWS S3 São Paulo (sa-east-1)**: Data remains in Brazil
2. **Backblaze B2**: Select US or EU region, but data is encrypted before upload
3. **On-premises NAS/SFTP**: Full control, data never leaves premises

### Encryption Strategy

**All data is encrypted BEFORE upload** using AES-256 encryption with your passphrase. This means:
- Backup provider cannot read your data (zero-knowledge encryption)
- Data is protected even if provider is breached
- Complies with LGPD encryption requirements

### Audit Trail

Duplicati maintains logs of all backup operations:
- Backup job execution history
- File versions and timestamps
- Restoration operations

Access logs via Duplicati web UI → **Log** tab

## Monitoring and Alerts

### Email Notifications (Optional)

Configure email notifications for backup success/failure:

1. Edit backup job
2. Go to **Options** → **Advanced**
3. Find **"Send mail"** options:
   - `send-mail-to`: Your email address
   - `send-mail-from`: noreply@{BORGSTACK_DOMAIN}
   - `send-mail-url`: `smtp://smtp.example.com:587`
   - `send-mail-username`: SMTP username
   - `send-mail-password`: SMTP password
4. Test email: Send a test backup report

### Webhook Notifications (n8n Integration)

For integration with n8n workflows:

1. Create n8n workflow with Webhook trigger
2. Edit backup job → **Options** → **Advanced**
3. Add **"Run script after backup"**:
   ```bash
   curl -X POST http://n8n:5678/webhook/backup-complete \
     -H "Content-Type: application/json" \
     -d '{"status":"$RESULT","job":"$BACKUP_NAME","time":"$TIMESTAMP"}'
   ```

## Troubleshooting

### Backup Fails: "Access Denied"

**Cause**: Duplicati cannot read Docker volumes
**Solution**: Verify Duplicati runs as root (PUID=0, PGID=0 in docker-compose.yml)

### Backup Fails: "Connection Error"

**Cause**: Cannot reach backup destination
**Solution**:
1. Check internet connectivity from Duplicati container:
   ```bash
   docker compose exec duplicati curl -I https://s3.amazonaws.com
   ```
2. Verify destination credentials
3. Test connection in Duplicati web UI

### Restoration Fails: "Wrong Passphrase"

**Cause**: Incorrect DUPLICATI_PASSPHRASE
**Solution**: **There is NO recovery if passphrase is lost!**
- Check password manager for correct passphrase
- Verify `.env` file has correct passphrase
- Try variations (spaces, special characters)

### High Storage Usage

**Cause**: Retention policy keeping too many versions
**Solution**:
1. Review retention policy (7D:1D,4W:1W,12M:1M)
2. Run **"Delete old backups"** manually
3. Adjust retention settings for less aggressive retention

## Security Best Practices

1. **Passphrase Security**:
   - Store in password manager (1Password, Bitwarden, LastPass)
   - Share with team via encrypted channels only
   - Write down and store in physical safe
   - NEVER commit passphrase to git

2. **Access Control**:
   - Change DUPLICATI_PASSWORD regularly (quarterly)
   - Use strong, unique passwords (minimum 32 characters)
   - Restrict web UI access via Caddy IP whitelist (optional)

3. **Backup Destination Security**:
   - Use dedicated credentials for backup storage (not admin accounts)
   - Enable MFA on backup provider account
   - Restrict bucket/folder permissions to write-only (append-only backups)

4. **Testing**:
   - Test restoration monthly
   - Document restoration procedures
   - Train team on disaster recovery process

## Files in This Directory

- `README.md` (this file): Comprehensive setup and usage documentation
- `backup-config-example.json`: Example backup job configuration (import template)
- `backup-job-template.json`: Pre-configured template with all sources selected

## Support and Documentation

- **Duplicati Documentation**: https://duplicati.readthedocs.io/
- **BorgStack Backup Guide**: `docs/03-services/duplicati.md` (Portuguese)
- **Disaster Recovery Guide**: `docs/04-integrations/backup-strategy.md` (Portuguese)
- **Restore Benchmarks**: `docs/04-integrations/restore-benchmarks.md`

## Manual Backup Commands

For emergency manual backups (if Duplicati is unavailable):

```bash
# PostgreSQL databases
docker compose exec postgresql pg_dumpall -U postgres > backup-postgresql-$(date +%Y%m%d).sql

# MongoDB
docker compose exec mongodb mongodump --username admin --password ${MONGODB_ROOT_PASSWORD} --authenticationDatabase admin --out /tmp/mongo-backup

# Volume tar backups (example: n8n)
docker compose exec n8n tar czf - /home/node/.n8n > n8n-backup-$(date +%Y%m%d).tar.gz
```

**Note**: These are emergency procedures. Duplicati automated backups are recommended for production.
