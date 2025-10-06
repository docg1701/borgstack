# SeaweedFS S3-Compatible Object Storage Configuration

SeaweedFS provides distributed S3-compatible object storage for BorgStack's file-heavy services (Directus CMS, FileFlows, Chatwoot, n8n).

## Architecture Overview

SeaweedFS runs in **unified server mode** where all components operate in a single container:

- **Master Server (port 9333)**: Volume allocation and topology management
- **Volume Server (port 8080)**: Actual file storage and retrieval operations
- **Filer (port 8888)**: File system abstraction layer with directory structure
- **S3 API (port 8333)**: S3-compatible HTTP interface for applications

This configuration is suitable for single-server deployments. For multi-server scaling, separate the components into dedicated containers.

## S3 API Access

### Internal Endpoint (Services)

All BorgStack services access SeaweedFS via the internal Docker network:

```
S3 Endpoint: http://seaweedfs:8333
Region: us-east-1 (configurable)
```

**Services using S3:**
- **Directus** (Story 5.3): CMS asset storage
- **FileFlows** (Story 5.3): Media processing via n8n workflows
- **Chatwoot**: Conversation file attachments
- **n8n**: Workflow attachments via HTTP Request nodes

### External Endpoint (Optional)

If you need S3 access from outside the Docker network (e.g., backup tools, mobile apps):

1. Uncomment the Caddy reverse proxy configuration (see `config/caddy/Caddyfile`)
2. Add `SEAWEEDFS_HOST=s3.${BORGSTACK_DOMAIN}` to `.env`
3. Add SeaweedFS to `borgstack_external` network in `docker-compose.yml`
4. Access via HTTPS: `https://s3.yourdomain.com`

**⚠️  Security Warning:** Only expose externally if absolutely required. Internal-only access is more secure.

## S3 Credentials

S3 credentials are configured via environment variables in `.env`:

```bash
SEAWEEDFS_ACCESS_KEY=<your-32-char-access-key>
SEAWEEDFS_SECRET_KEY=<your-64-char-secret-key>
```

**Generate strong credentials:**

```bash
# Access Key (32 chars)
openssl rand -base64 24

# Secret Key (64 chars)
openssl rand -base64 48
```

Store these credentials securely - they are required for all S3 client access.

## Bucket Organization

SeaweedFS uses a single main bucket with subdirectories for each service:

```
/buckets/
  borgstack/                    # Main bucket
    n8n/                        # n8n workflow attachments
    chatwoot/                   # Chatwoot conversation files
      avatars/
      messages/
      uploads/
    directus/                   # Directus CMS assets
      originals/
      thumbnails/
      documents/
    fileflows/                  # FileFlows processed media
      input/
      output/
      temp/
    lowcoder/                   # Lowcoder app assets
    duplicati/                  # Backup staging area
```

**Why a single bucket with prefixes?**
- Simpler permission management (bucket-level policies)
- Easier to backup (single bucket snapshot)
- Consistent S3 endpoint across all services
- Aligns with S3 best practices

## Volume Management

### Volume Configuration

SeaweedFS stores files in **volumes** - large pre-allocated files that contain multiple smaller files:

- **Volume Size Limit**: 10GB per volume (configurable via `SEAWEEDFS_VOLUME_SIZE_LIMIT_MB`)
- **Max Volumes**: 100 volumes (configurable via `SEAWEEDFS_MAX_VOLUMES`)
- **Total Capacity**: Volume Size × Max Volumes = 1TB default

### Check Cluster Status

```bash
# Get cluster health and statistics
curl http://localhost:9333/cluster/status

# View volume topology and distribution
curl http://localhost:9333/dir/status

# List all volumes
curl http://localhost:9333/vol/status
```

### Manual Volume Growth

SeaweedFS automatically creates new volumes when existing ones fill up. To pre-allocate volumes manually:

```bash
# Grow by 4 volumes with 000 replication
curl "http://localhost:9333/vol/grow?count=4&replication=000"

# Verify new volumes created
curl http://localhost:9333/dir/status
```

### Monitor Storage Usage

```bash
# Check disk usage in volume directory
docker compose exec seaweedfs df -h /data/volume

# Check filer database size
docker compose exec seaweedfs du -sh /data/filer

# Check master metadata size
docker compose exec seaweedfs du -sh /data/master
```

## Replication Strategy

### Current Configuration (Single Server)

```bash
SEAWEEDFS_REPLICATION=000
```

**Format**: `XYZ` where:
- **X** = Copies in different datacenters
- **Y** = Copies in different racks
- **Z** = Copies on different servers

**`000`** = No replication (single server mode)

### Multi-Server Expansion

When adding servers for redundancy:

1. Update `.env`:
   ```bash
   SEAWEEDFS_REPLICATION=001  # 1 copy on different server
   ```

2. Deploy additional SeaweedFS volume servers

3. Restart SeaweedFS master to recognize new topology:
   ```bash
   docker compose restart seaweedfs
   ```

4. Verify cluster topology:
   ```bash
   curl http://localhost:9333/cluster/status
   ```

**Replication Options:**
- `001` = 1 server copy (2 total copies across 2 servers)
- `011` = 1 rack copy + 1 server copy (requires 2+ racks)
- `100` = 1 datacenter copy (requires 2+ datacenters)

## Directory Quotas (Optional)

Prevent individual services from consuming all storage by configuring directory quotas in `filer.toml`:

```toml
# Limit Directus to 300GB
[quota.buckets.borgstack.directus]
max_mb = 307200

# Limit FileFlows to 500GB
[quota.buckets.borgstack.fileflows]
max_mb = 512000
```

After updating `filer.toml`:

```bash
# Restart SeaweedFS to apply quota changes
docker compose restart seaweedfs

# Verify quotas applied
curl http://localhost:8888/
```

## S3 Client Configuration

### AWS CLI

```bash
# Configure AWS CLI with SeaweedFS credentials
aws configure set aws_access_key_id ${SEAWEEDFS_ACCESS_KEY}
aws configure set aws_secret_access_key ${SEAWEEDFS_SECRET_KEY}
aws configure set default.region us-east-1
aws configure set default.s3.signature_version s3v4

# List buckets
aws --endpoint-url http://localhost:8333 s3 ls

# List files in borgstack bucket
aws --endpoint-url http://localhost:8333 s3 ls s3://borgstack/

# Upload file
aws --endpoint-url http://localhost:8333 s3 cp test.txt s3://borgstack/n8n/

# Download file
aws --endpoint-url http://localhost:8333 s3 cp s3://borgstack/n8n/test.txt ./
```

### s3cmd

Create `~/.s3cfg`:

```ini
[default]
access_key = <SEAWEEDFS_ACCESS_KEY>
secret_key = <SEAWEEDFS_SECRET_KEY>
host_base = localhost:8333
host_bucket = localhost:8333/%(bucket)
use_https = False
signature_v2 = False
```

Usage:

```bash
# List buckets
s3cmd ls

# Upload file
s3cmd put test.txt s3://borgstack/n8n/

# Download file
s3cmd get s3://borgstack/n8n/test.txt
```

### Python boto3

```python
import boto3
from botocore.client import Config

# Create S3 client
s3 = boto3.client(
    's3',
    endpoint_url='http://seaweedfs:8333',
    aws_access_key_id='<SEAWEEDFS_ACCESS_KEY>',
    aws_secret_access_key='<SEAWEEDFS_SECRET_KEY>',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# List buckets
response = s3.list_buckets()
print([b['Name'] for b in response['Buckets']])

# Upload file
s3.upload_file('local.txt', 'borgstack', 'n8n/local.txt')

# Download file
s3.download_file('borgstack', 'n8n/local.txt', 'downloaded.txt')

# Generate presigned URL (temporary public link)
url = s3.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'borgstack', 'Key': 'n8n/file.txt'},
    ExpiresIn=3600  # 1 hour
)
print(url)
```

## Integration with BorgStack Services

### Directus CMS (Story 5.3)

Directus will be migrated from local volume storage to SeaweedFS S3:

```bash
# .env configuration (applied in Story 5.3)
STORAGE_LOCATIONS=s3
STORAGE_S3_DRIVER=s3
STORAGE_S3_KEY=${SEAWEEDFS_ACCESS_KEY}
STORAGE_S3_SECRET=${SEAWEEDFS_SECRET_KEY}
STORAGE_S3_BUCKET=borgstack
STORAGE_S3_REGION=us-east-1
STORAGE_S3_ENDPOINT=http://seaweedfs:8333
STORAGE_S3_ROOT=/directus/
```

### FileFlows Media Processing (Story 5.3)

FileFlows doesn't natively support S3. Integration uses n8n workflows:

1. n8n downloads media from SeaweedFS to FileFlows `/input` volume
2. FileFlows processes media → outputs to `/output` volume
3. n8n uploads processed media from `/output` back to SeaweedFS

### Chatwoot (Story 5.3)

Chatwoot will use SeaweedFS for conversation file attachments:

```bash
# .env configuration (applied in Story 5.3)
ACTIVE_STORAGE_SERVICE=s3
AWS_ACCESS_KEY_ID=${SEAWEEDFS_ACCESS_KEY}
AWS_SECRET_ACCESS_KEY=${SEAWEEDFS_SECRET_KEY}
AWS_REGION=us-east-1
AWS_BUCKET_NAME=borgstack
AWS_S3_ENDPOINT=http://seaweedfs:8333
AWS_S3_PATH_PREFIX=chatwoot/
```

### n8n Workflow Attachments

n8n uses HTTP Request nodes with AWS SDK integration for S3 operations. See example workflows in `config/n8n/workflows/`.

## Troubleshooting

### Container Won't Start

```bash
# Check SeaweedFS logs
docker compose logs seaweedfs --tail=100

# Common issues:
# - Missing S3 credentials in .env
# - Volume permission errors
# - Port conflicts

# Verify health check
docker compose ps seaweedfs
```

### S3 API Returns 403 Forbidden

```bash
# Verify credentials are correct
docker compose exec seaweedfs printenv | grep AWS

# Test master API (no auth required)
curl http://localhost:9333/cluster/status

# Test S3 API with credentials
curl -u ${SEAWEEDFS_ACCESS_KEY}:${SEAWEEDFS_SECRET_KEY} http://localhost:8333/
```

### Volumes Not Growing Automatically

```bash
# Check volume status
curl http://localhost:9333/dir/status

# Manually trigger volume growth
curl "http://localhost:9333/vol/grow?count=4&replication=000"

# Verify SEAWEEDFS_MAX_VOLUMES not reached
docker compose exec seaweedfs printenv | grep MAX_VOLUMES
```

### Filer Metadata Corruption

```bash
# Stop SeaweedFS
docker compose stop seaweedfs

# Backup filer data
docker compose exec -T seaweedfs tar czf - /data/filer > filer-backup.tar.gz

# Restart with filer rebuild (last resort)
docker compose up -d seaweedfs

# Check filer logs
docker compose logs seaweedfs --tail=50
```

### Performance Issues

```bash
# Check disk I/O performance
docker compose exec seaweedfs sh -c "dd if=/dev/zero of=/data/volume/test.dat bs=1M count=1000 oflag=direct"

# Expected: >100 MB/s for SSD storage

# Monitor volume distribution (avoid hotspots)
curl http://localhost:9333/dir/status

# Enable volume pre-allocation for consistent performance
# Update .env:
SEAWEEDFS_VOLUME_PREALLOCATE=true

# Restart SeaweedFS
docker compose restart seaweedfs
```

## Backup and Recovery

SeaweedFS volumes are backed up by Duplicati (Story 5.2). Manual backup:

```bash
# Backup all three volumes
docker compose exec -T seaweedfs tar czf - /data/master > seaweedfs-master-$(date +%Y%m%d).tar.gz
docker compose exec -T seaweedfs tar czf - /data/volume > seaweedfs-volume-$(date +%Y%m%d).tar.gz
docker compose exec -T seaweedfs tar czf - /data/filer > seaweedfs-filer-$(date +%Y%m%d).tar.gz
```

**⚠️  All three volumes are required for recovery:**
- `master`: Cluster topology and volume allocation metadata
- `volume`: Actual file content in chunks
- `filer`: S3 path → volume chunk mapping

## Security Best Practices

1. **Never commit S3 credentials to version control**
   - Store in `.env` with 600 permissions
   - Rotate credentials periodically

2. **Use internal network only (default)**
   - No external S3 access unless required
   - Expose via Caddy HTTPS only if necessary

3. **Enable directory quotas**
   - Prevent storage exhaustion attacks
   - Limit per-service storage consumption

4. **Monitor access logs**
   - Review S3 API access patterns
   - Detect unauthorized access attempts

5. **Regular backups**
   - Automated via Duplicati (Story 5.2)
   - Test restore procedures quarterly

6. **Update credentials after team changes**
   - Rotate S3 keys when staff leave
   - Use separate credentials for different environments

## Performance Optimization

1. **Use SSD storage for `/data/volume`**
   - Target: >100 MB/s sequential read/write
   - Check: `dd` benchmark (see Troubleshooting)

2. **Pre-allocate volumes during low-traffic periods**
   - Reduces fragmentation
   - Improves write performance

3. **Monitor volume distribution**
   - Ensure even file distribution across volumes
   - Prevent volume hotspots

4. **Increase max volumes if needed**
   - Default: 100 volumes (1TB capacity)
   - Increase for larger storage requirements

5. **Enable volume pre-allocation**
   - Set `SEAWEEDFS_VOLUME_PREALLOCATE=true`
   - Trades upfront disk space for consistent performance

## Additional Resources

- [SeaweedFS GitHub](https://github.com/seaweedfs/seaweedfs)
- [SeaweedFS Wiki](https://github.com/seaweedfs/seaweedfs/wiki)
- [S3 API Compatibility](https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API)
- [Filer Configuration](https://github.com/seaweedfs/seaweedfs/wiki/Filer-Stores)
- [Replication Strategy](https://github.com/seaweedfs/seaweedfs/wiki/Replication)

## Next Steps

After SeaweedFS deployment (Story 5.1):

1. **Story 5.2**: Deploy Duplicati for automated SeaweedFS backups
2. **Story 5.3**: Migrate Directus and FileFlows from local volumes to SeaweedFS S3
3. **Story 5.4**: Configure Chatwoot to use SeaweedFS for attachments
4. **Story 6.x**: Create n8n workflow templates for S3 operations

---

For deployment validation, run:
```bash
./tests/deployment/verify-seaweedfs.sh
```
