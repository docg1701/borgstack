# FileFlows Media Processing Configuration

FileFlows 25.09 automated media file conversion and processing platform.

## Table of Contents

1. [Accessing FileFlows](#accessing-fileflows)
2. [Initial Setup Wizard](#initial-setup-wizard)
3. [Processing Node Configuration](#processing-node-configuration)
4. [Library Configuration](#library-configuration)
5. [Flow Creation Basics](#flow-creation-basics)
6. [Example Flows](#example-flows)
7. [Integration with BorgStack Services](#integration-with-borgstack-services)
8. [Troubleshooting](#troubleshooting)
9. [Future Enhancements](#future-enhancements)

## Accessing FileFlows

**Web UI URL:** `https://fileflows.${DOMAIN}`

Example: `https://fileflows.example.com.br`

**Requirements:**
- DNS A record for `fileflows.${DOMAIN}` pointing to your server IP
- Caddy reverse proxy configured (automatic HTTPS)
- FileFlows container running: `docker compose ps fileflows`

**First-time Access:**
On first launch, FileFlows will display the initial setup wizard to create an admin account and configure the processing node.

## Initial Setup Wizard

### Step 1: Create Admin Account

1. Navigate to `https://fileflows.${DOMAIN}`
2. You will be prompted to create an admin account
3. Enter **admin email** (e.g., `admin@example.com.br`)
4. Enter **admin password** (strong password recommended)
5. Click **Create Account**

### Step 2: Configure Processing Node

FileFlows uses "Processing Nodes" to execute media processing workflows. At minimum, one processing node is required.

**Local Server Node (Default):**
- **Node Name:** `BorgStack Local Server` (or custom name)
- **Temp Directory:** `/temp` (already configured in docker-compose.yml)
- **Concurrent Processing:** `2` (for 8 vCPU server - adjust based on CPU cores)
- **Enabled:** ✅ Yes

**Node Capacity Guidelines:**
- **Light workload:** 1-2 concurrent jobs per 4 CPU cores
- **Heavy workload:** 1 concurrent job per 4 CPU cores (CPU-intensive transcoding)
- **Server with 8 vCPUs:** Start with 2 concurrent jobs, monitor CPU usage

Click **Save** to create the processing node.

### Step 3: Verify FFmpeg

FileFlows uses FFmpeg for media processing. The Docker image includes FFmpeg by default.

**Verify FFmpeg Installation:**
1. Go to **Settings** → **System**
2. Scroll to **FFmpeg** section
3. Verify **FFmpeg Path:** `/usr/bin/ffmpeg` (pre-installed in container)
4. Click **Test FFmpeg** to verify codecs are available

Expected output: ✅ FFmpeg working correctly

## Processing Node Configuration

### Node Settings

**Location:** Settings → Processing Nodes

**Key Settings:**
- **Node Name:** Descriptive name (e.g., "BorgStack Local Server")
- **Enabled:** ✅ Enable node for processing
- **Temp Directory:** `/temp` (scratch space for FFmpeg - ensure adequate disk space)
- **Max Parallel Jobs:** Number of concurrent media files to process
- **Schedule:** Optional - restrict processing to specific hours (e.g., off-peak)

### Hardware Transcoding (Optional)

If your server has a GPU, you can enable hardware transcoding for faster processing:

1. Pass GPU to Docker container (requires `--gpus all` in docker-compose.yml)
2. Configure FFmpeg to use hardware encoder:
   - **NVIDIA:** `-c:v h264_nvenc` (H.264), `-c:v hevc_nvenc` (H.265)
   - **Intel Quick Sync:** `-c:v h264_qsv` (H.264), `-c:v hevc_qsv` (H.265)
   - **AMD:** `-c:v h264_amf` (H.264), `-c:v hevc_amf` (H.265)

**Note:** Hardware transcoding is optional. Software encoding (libx264/libx265) works on all systems.

## Library Configuration

FileFlows monitors "Libraries" (directories) for new files to process.

### Creating a Library

1. Go to **Libraries** → **Add Library**
2. Configure library settings:

**Input Library (Media Files Awaiting Processing):**
- **Name:** `Media Input`
- **Path:** `/input`
- **Scan Interval:** `60 seconds` (check for new files every minute)
- **Enabled:** ✅ Yes
- **File Pattern:** `*.*` (all files) or specific extensions (e.g., `*.mp4,*.mkv,*.avi`)

**Output Library (Processed Media Files):**
- FileFlows automatically places processed files in the output directory defined in the flow
- No separate library configuration needed for output

Click **Save** to create the library.

### Library Watch Mode

FileFlows watches the input library directory (`/input`) for new files. When a new file is detected:

1. FileFlows checks if the file matches a **Flow** filter (file extension, size, etc.)
2. If matched, the Flow is triggered automatically
3. Processing begins on the next available Processing Node slot

## Flow Creation Basics

Flows are visual processing pipelines: **Input** → **Processing Steps** → **Output**

### Creating a Flow

1. Go to **Flows** → **Add Flow**
2. Enter **Flow Name** (e.g., "Video H.264 Transcode")
3. Click **Create** to open the Flow Designer

### Flow Designer Interface

- **Canvas:** Drag and drop processing nodes
- **Toolbox (Left):** Available processing nodes
- **Properties (Right):** Configure selected node

### Basic Flow Structure

```
[Input File] → [File Filter] → [FFmpeg Process] → [Move File] → [Output]
```

**Example: Video Transcoding Flow**

1. **Input:** Automatic (file from library)
2. **File Filter:** Check if file is a video (e.g., `.mp4`, `.mkv`, `.avi`)
3. **FFmpeg:** Transcode to H.264 (`-c:v libx264 -crf 23 -preset medium`)
4. **Move File:** Move processed file to `/output`
5. **Output:** Complete (processed file ready)

### Common Processing Nodes

**File Operations:**
- **File Filter:** Check file extension, size, or other properties
- **Move File:** Move file to output directory
- **Delete File:** Remove original file after processing
- **Rename File:** Change filename (e.g., add `-transcoded` suffix)

**FFmpeg Processing:**
- **FFmpeg:** Execute custom FFmpeg command
- **Video Encode:** Transcode video (H.264, H.265, VP9, AV1)
- **Audio Encode:** Transcode audio (AAC, MP3, Opus, FLAC)
- **Resize Video:** Change resolution (1080p → 720p, etc.)
- **Normalize Audio:** Apply loudness normalization (loudnorm filter)

**Conditional Logic:**
- **If Condition:** Branch based on file properties (e.g., if video resolution > 1080p)
- **Switch:** Multi-branch based on file extension or other criteria

**Notifications:**
- **Webhook:** Send HTTP POST to n8n or other service on completion
- **Log:** Write custom log message

### Flow Example: Video H.264 Transcode

**Goal:** Convert all video files to H.264 with CRF 23 (balanced quality)

**Flow Steps:**
1. **Input:** File from `/input` library
2. **File Filter:** Check extension is `.mp4`, `.mkv`, `.avi`, `.mov`, or `.webm`
3. **FFmpeg:** Transcode to H.264
   - Command: `-c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k`
   - CRF 23 = Balanced quality (lower = higher quality, higher file size)
   - Preset medium = Balanced speed (faster = lower quality, slower = higher quality)
   - Audio: AAC 128kbps
4. **Move File:** Move to `/output/{filename}.mp4`
5. **Delete Original:** (Optional) Remove original file from `/input`

**Enable Flow:** Toggle **Enabled** switch in Flow settings

**Test Flow:** Upload a test video to `/input` directory:
```bash
docker compose cp test-video.mp4 fileflows:/input/
```

Monitor processing in **Processing** → **Active Jobs**

## Example Flows

See `example-flows.json` in this directory for pre-configured flow templates:

1. **Video H.264 Transcoding:** Convert videos to H.264 (libx264, CRF 23)
2. **Audio Normalization:** Normalize audio levels using loudnorm filter
3. **Image WebP Conversion:** Convert images to WebP format (80% quality)

**Import Flows:**
1. Go to **Flows** → **Import**
2. Select `example-flows.json`
3. Click **Import**

Flows will be created in disabled state. Review and enable as needed.

## Integration with BorgStack Services

FileFlows integrates with other BorgStack services via n8n workflows:

### Workflow 1: Directus Upload → FileFlows Processing

**Trigger:** User uploads video to Directus CMS

**Workflow:**
1. User uploads video to Directus (stored in `/uploads` volume)
2. Directus triggers n8n webhook with file metadata
3. n8n copies file from Directus uploads to FileFlows input: `/directus/uploads/{file}` → `/input/{file}`
4. FileFlows detects new file and starts processing
5. FileFlows processes file (transcode H.264) and outputs to `/output`
6. FileFlows webhooks n8n with completion status
7. n8n updates Directus with processed file URL

**n8n Flow:**
- Webhook Trigger (Directus → n8n)
- Copy File (Directus uploads → FileFlows input)
- Wait for Webhook (FileFlows → n8n)
- Update Directus (set processed file URL)

### Workflow 2: Manual Processing via n8n

**Trigger:** n8n HTTP request from Lowcoder app or external system

**Workflow:**
1. External system calls n8n: `POST /webhook/process-media` with file URL
2. n8n downloads file to FileFlows input: `wget {url} -O /input/{filename}`
3. FileFlows processes file automatically
4. n8n receives completion webhook from FileFlows
5. n8n returns processed file URL to caller

**n8n Flow:**
- HTTP Trigger
- Download File → `/input`
- Wait for Webhook (FileFlows completion)
- Respond with processed file URL

## Troubleshooting

### FileFlows Container Not Starting

**Check logs:**
```bash
docker compose logs fileflows --tail=100
```

**Common issues:**
- **Permission errors:** Verify PUID/PGID match host user (`id -u && id -g`)
- **Volume mount errors:** Ensure `/input`, `/output`, `/temp` directories are accessible

### Processing Fails

**Check FFmpeg logs:**
1. Go to **Processing** → **History**
2. Click failed job
3. View **Log Output** for FFmpeg errors

**Common FFmpeg errors:**
- **Codec not supported:** Verify FFmpeg has required codec: `docker compose exec fileflows ffmpeg -codecs | grep {codec}`
- **Out of disk space:** Check `/temp` volume has adequate space
- **Corrupted input file:** Verify file integrity: `ffprobe {file}`

### File Not Detected

**Verify library configuration:**
1. Go to **Libraries**
2. Ensure library **Enabled:** ✅ Yes
3. Ensure library **Path:** `/input` is correct
4. Ensure **File Pattern:** matches your files (e.g., `*.mp4`)

**Check library scan:**
1. Go to **Libraries** → **Media Input**
2. Click **Scan Now** to force library rescan

**Verify file permissions:**
```bash
docker compose exec fileflows ls -la /input
```

Files must be readable by the container user (PUID/PGID).

### Web UI Not Accessible

**Verify Caddy routing:**
```bash
docker compose logs caddy | grep fileflows
```

**Verify FileFlows container health:**
```bash
docker compose ps fileflows
```

Expected status: `Up (healthy)`

**Test direct container access:**
```bash
docker compose exec caddy curl http://fileflows:5000/
```

Expected response: HTML page (FileFlows UI)

### Performance Issues

**Reduce concurrent processing:**
1. Go to **Settings** → **Processing Nodes**
2. Reduce **Max Parallel Jobs** to `1`
3. Monitor server CPU/RAM usage: `docker stats fileflows`

**Monitor server resources during processing:**
```bash
docker stats fileflows
```

Watch **CPU %** and **MEM USAGE** columns.

**For large files:**
- Ensure `/temp` volume has adequate space (temp files can be 2-3x input file size during processing)
- Consider using faster encoding preset (`-preset fast` instead of `-preset medium`)

## Future Enhancements

### S3 Storage Migration (Story 5.1 - SeaweedFS)

**Current Implementation (Story 4.2):**
FileFlows uses local Docker volumes for file storage:
- Input: `borgstack_fileflows_input` (mounted at `/input`)
- Output: `borgstack_fileflows_output` (mounted at `/output`)
- Temp: `borgstack_fileflows_temp` (mounted at `/temp`)

**Future Implementation (Story 5.1):**
FileFlows will migrate to SeaweedFS S3-compatible storage for scalability and performance.

**Benefits of S3 Migration:**
- **Scalability:** Unlimited storage capacity (SeaweedFS distributed architecture)
- **Performance:** Faster file access with distributed reads/writes
- **Integration:** Shared storage with Directus, n8n, and other services
- **Backup:** Centralized backup of all media files via SeaweedFS

**Migration Steps (Story 5.1):**
1. Deploy SeaweedFS S3-compatible storage (Story 5.1)
2. Copy existing files from local volumes to SeaweedFS:
   ```bash
   docker compose exec seaweedfs s3cmd put --recursive \
     /mnt/borgstack_fileflows_input/ \
     s3://borgstack/fileflows/input/

   docker compose exec seaweedfs s3cmd put --recursive \
     /mnt/borgstack_fileflows_output/ \
     s3://borgstack/fileflows/output/
   ```
3. Update FileFlows configuration with S3 credentials (see `s3-storage.env.example`)
4. Update docker-compose.yml to use S3 storage instead of local volumes
5. Restart FileFlows: `docker compose up -d fileflows`
6. Verify S3 connectivity and processing works
7. Archive local volumes after successful migration

**S3 Storage Template:**
See `s3-storage.env.example` in this directory for environment variables required for S3 migration.

**SeaweedFS Bucket Structure (Story 5.1):**
```
/borgstack/fileflows/
  ├── input/       # Input media files (watch directory)
  ├── output/      # Processed media files
  └── temp/        # Temporary processing files (FFmpeg scratch space)
```

**S3 Configuration (Story 5.1):**
- **Endpoint:** `http://seaweedfs:8333` (internal Docker network)
- **Bucket:** `borgstack`
- **Input Prefix:** `fileflows/input/`
- **Output Prefix:** `fileflows/output/`
- **Temp Prefix:** `fileflows/temp/`

**No Action Required (Story 4.2):**
This migration will be implemented in Story 5.1. Current local volume storage is production-ready.

---

**Questions or Issues?**
- Check logs: `docker compose logs fileflows --tail=100`
- Check health: `docker compose ps fileflows`
- Community: FileFlows Discord (https://discord.gg/fileflows)
