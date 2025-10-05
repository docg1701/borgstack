# FileFlows Configuration for Directus Integration

This guide covers manual configuration for FileFlows media processing integration with Directus via n8n.

## Task 5: Configure FileFlows Webhooks for Completion Notifications

### Overview
Configure FileFlows to send webhook notifications to n8n when media processing completes (success or failure).

### Steps

#### 1. Access FileFlows Admin Panel
```
URL: https://fileflows.${DOMAIN}
```

**Note:** FileFlows may not have built-in authentication on first startup. Secure it immediately:
- Go to **Settings → Security**
- Enable authentication
- Set admin password

#### 2. Navigate to Webhooks Configuration
- Click **Settings** (gear icon) in sidebar
- Select **Webhooks** or **Notifications**
  - **Note:** Exact menu name depends on FileFlows version
  - May also be under **Settings → System → Webhooks**

#### 3. Create Webhook: Processing Complete
Click **"Add Webhook"** or **"Create New"**

**Webhook Name:** `Processing Complete Notification`

**Trigger Event:** `Flow Execution Complete`
- Alternative names: "Processing Complete", "Job Finished", "Execution Success"

**URL:** `https://n8n.${DOMAIN}/webhook/fileflows-complete`

**Method:** POST

**Payload Template:**
```json
{
  "original_filename": "{{OriginalFilename}}",
  "processed_filename": "{{ProcessedFilename}}",
  "output_path": "{{OutputPath}}",
  "status": "{{Status}}",
  "metadata": {
    "processing_time": {{ProcessingTime}},
    "codec": "{{Codec}}",
    "resolution": "{{Resolution}}",
    "filesize_original": {{OriginalFilesize}},
    "filesize_processed": {{ProcessedFilesize}},
    "compression_ratio": {{CompressionRatio}}
  }
}
```

**⚠️ IMPORTANT:** Exact variable names depend on FileFlows version. Check FileFlows documentation or use webhook builder to see available variables.

**Retry Configuration:**
- **Retry on Failure:** Yes
- **Retry Attempts:** 3
- **Retry Delays:** 5s, 10s, 20s (exponential backoff)

**Save** the webhook.

#### 4. Create Webhook: Processing Error
Click **"Add Webhook"** again

**Webhook Name:** `Processing Error Notification`

**Trigger Event:** `Flow Execution Failed`
- Alternative names: "Processing Failed", "Job Error", "Execution Error"

**URL:** `https://n8n.${DOMAIN}/webhook/fileflows-error`

**Method:** POST

**Payload Template:**
```json
{
  "original_filename": "{{OriginalFilename}}",
  "error_message": "{{ErrorMessage}}",
  "error_code": "{{ErrorCode}}",
  "status": "failed",
  "metadata": {
    "failed_at_step": "{{FailedStep}}",
    "processing_time": {{ProcessingTime}},
    "stack_trace": "{{StackTrace}}"
  }
}
```

**Retry Configuration:**
- **Retry on Failure:** Yes
- **Retry Attempts:** 3
- **Retry Delays:** 5s, 10s, 20s

**Save** the webhook.

#### 5. Test Webhooks
**Test Complete Webhook:**
1. Find webhook in list
2. Click **"Test"** or **"Send Test"** button
3. Check n8n execution log for test event

**Test Error Webhook:**
1. Find error webhook in list
2. Click **"Test"** button
3. Check n8n execution log for test event

### Verification

Check n8n received test webhooks:
1. Access n8n: `https://n8n.${DOMAIN}`
2. Go to **Executions** tab
3. Look for:
   - **"FileFlows → Directus Update Results"** execution
   - **"FileFlows Error Handler"** execution
4. Verify both executed successfully (even with test data)

---

## Task 6: Create FileFlows Processing Flows for Common Media Types

### Overview
Create automated processing workflows (Flows) for video transcoding, audio normalization, and image optimization.

### Prerequisites
- FileFlows Processing Node configured
- Verify FFmpeg is available in FileFlows container

### Flow 1: Video Optimization H.264

#### 1. Create New Flow
- Click **Flows** in sidebar
- Click **"Add Flow"** or **"New Flow"**

**Flow Name:** `Video Optimization H.264`

**Flow Description:** Transcode videos to H.264 codec with optimized bitrate and resolution

#### 2. Configure Flow Trigger
**Input:**
- **Input Directory:** `/input`
- **File Pattern:** `*.mp4, *.avi, *.mkv, *.mov, *.wmv, *.flv, *.webm`
- **Watch Mode:** Auto-detect new files
- **Polling Interval:** 60 seconds

#### 3. Add Processing Steps

**Step 1: Video Codec Detection**
- **Node Type:** FFmpeg - Inspect
- **Purpose:** Detect video codec, resolution, bitrate
- **Output:** Save to variables

**Step 2: Conditional - Check if Already H.264**
- **Node Type:** If Condition
- **Condition:** `VideoCodec != "h264"`
- **TRUE:** Continue to transcode
- **FALSE:** Skip transcoding (already optimized)

**Step 3: FFmpeg Transcode**
- **Node Type:** FFmpeg - Encode
- **Codec:** H.264 (libx264)
- **Quality:** CRF 23 (balanced quality/size)
  - CRF 18-22: High quality (larger files)
  - CRF 23-25: Balanced (recommended)
  - CRF 26-28: Lower quality (smaller files)
- **Preset:** medium
  - ultrafast, superfast, veryfast: Faster encoding, larger files
  - medium: Balanced (recommended)
  - slow, slower, veryslow: Slower encoding, smaller files
- **Audio Codec:** AAC 192kbps
- **Resolution:** Max 1920x1080 (maintain aspect ratio)
- **Output Format:** MP4
- **Output Path:** `/output/video/{filename}.mp4`

**Step 4: Cleanup (Optional)**
- **Node Type:** Delete Source File
- **Condition:** `ProcessingStatus == "success"`
- **Purpose:** Delete original file after successful processing
- **⚠️ WARNING:** Only enable if `FILEFLOWS_DELETE_ORIGINALS=true` in .env

#### 4. Save and Activate Flow
- Click **"Save"**
- Toggle **"Active"** (enable)

---

### Flow 2: Audio Normalization

#### 1. Create New Flow
**Flow Name:** `Audio Normalization`

**Flow Description:** Normalize audio levels and convert to MP3 320kbps

#### 2. Configure Flow Trigger
**Input:**
- **Input Directory:** `/input`
- **File Pattern:** `*.mp3, *.wav, *.flac, *.m4a, *.aac, *.ogg, *.wma`
- **Watch Mode:** Auto-detect new files

#### 3. Add Processing Steps

**Step 1: Audio Analysis**
- **Node Type:** FFmpeg - Audio Analyze
- **Purpose:** Detect audio format, bitrate, sample rate

**Step 2: Loudness Normalization**
- **Node Type:** FFmpeg - Audio Filter
- **Filter:** loudnorm
  - **Target Loudness:** -16 LUFS (standard for streaming)
  - **Peak Level:** -1.5 dBTP
  - **Loudness Range:** 11 LU

**Step 3: Convert to MP3**
- **Node Type:** FFmpeg - Encode
- **Codec:** MP3 (libmp3lame)
- **Bitrate:** 320kbps (high quality)
- **Sample Rate:** 48kHz
- **Channels:** Stereo (or maintain original if mono)
- **Output Path:** `/output/audio/{filename}.mp3`

**Step 4: Cleanup (Optional)**
- **Node Type:** Delete Source File
- **Condition:** `ProcessingStatus == "success"`

#### 4. Save and Activate Flow

---

### Flow 3: Image WebP Conversion

#### 1. Create New Flow
**Flow Name:** `Image WebP Conversion`

**Flow Description:** Convert images to WebP format with compression and resizing

#### 2. Configure Flow Trigger
**Input:**
- **Input Directory:** `/input`
- **File Pattern:** `*.jpg, *.jpeg, *.png, *.bmp, *.tiff`
- **Watch Mode:** Auto-detect new files

#### 3. Add Processing Steps

**Step 1: Image Analysis**
- **Node Type:** FFmpeg - Image Inspect
- **Purpose:** Get image dimensions, format, color space

**Step 2: Resize (if needed)**
- **Node Type:** FFmpeg - Image Scale
- **Max Dimensions:** 1920x1080 (maintain aspect ratio)
- **Scaling Filter:** lanczos (high quality)
- **Condition:** Only resize if width > 1920 OR height > 1080

**Step 3: Convert to WebP**
- **Node Type:** FFmpeg - Image Encode
- **Codec:** WebP
- **Quality:** 85 (balanced)
  - 90-100: High quality (larger files)
  - 80-85: Balanced (recommended)
  - 70-75: Lower quality (smaller files)
- **Compression:** lossy
- **Output Path:** `/output/images/{filename}.webp`

**Step 4: Cleanup (Optional)**
- **Node Type:** Delete Source File
- **Condition:** `ProcessingStatus == "success"`

#### 4. Save and Activate Flow

---

### Export Flows (Configuration Backup)

After creating all flows:

1. Go to **Settings → Flows** or **Flows** page
2. Select all 3 flows
3. Click **"Export"** button
4. Save as: `directus-integration-flows.json`
5. Copy to BorgStack repository:
   ```bash
   cp ~/Downloads/directus-integration-flows.json \
      /home/galvani/dev/borgstack/config/fileflows/
   ```

This backup allows recreating flows after container restart or migration.

---

## Testing

### Test Flow 1: Video Optimization

**Prepare Test Video:**
```bash
# Download public domain test video
wget -O test-video.mp4 \
  https://filesamples.com/samples/video/mp4/sample_1920x1080.mp4

# Copy to FileFlows input
docker compose exec -w /input fileflows sh -c \
  "cat > test-video.mp4" < test-video.mp4
```

**Monitor Processing:**
1. Access FileFlows UI: `https://fileflows.${DOMAIN}`
2. Go to **Processing** or **Jobs** page
3. Wait for "Video Optimization H.264" flow to start
4. Monitor progress (should take 1-2 minutes for 10MB video)

**Verify Output:**
```bash
# Check output directory
docker compose exec fileflows ls -lh /output/video/

# Verify processed file exists
docker compose exec fileflows file /output/video/test-video.mp4
```

**Expected:**
- File exists in `/output/video/`
- File is smaller than original (if CRF > original quality)
- Codec is H.264 (verify with `ffprobe`)

### Test Flow 2: Audio Normalization

**Prepare Test Audio:**
```bash
# Download test audio
wget -O test-audio.mp3 \
  https://filesamples.com/samples/audio/mp3/sample3.mp3

# Copy to FileFlows input
docker compose exec -w /input fileflows sh -c \
  "cat > test-audio.mp3" < test-audio.mp3
```

**Verify Output:**
```bash
docker compose exec fileflows ls -lh /output/audio/
```

### Test Flow 3: Image WebP Conversion

**Prepare Test Image:**
```bash
# Download test image
wget -O test-image.jpg \
  https://filesamples.com/samples/image/jpg/sample_1920×1280.jpg

# Copy to FileFlows input
docker compose exec -w /input fileflows sh -c \
  "cat > test-image.jpg" < test-image.jpg
```

**Verify Output:**
```bash
docker compose exec fileflows ls -lh /output/images/
file /output/images/test-image.webp
```

---

## Troubleshooting

### Flow not processing files
- Verify flow is **Active** (enabled)
- Check input directory: `docker compose exec fileflows ls /input/`
- Check FileFlows logs: `docker compose logs fileflows`
- Verify file matches pattern (*.mp4, *.jpg, etc.)

### FFmpeg errors
- Check FFmpeg is installed: `docker compose exec fileflows ffmpeg -version`
- Review processing logs in FileFlows UI
- Verify file format is supported by FFmpeg

### Webhook not firing
- Verify webhooks are configured (Task 5)
- Check webhook test succeeded
- Review FileFlows webhook logs (if available)

### Output file not created
- Check disk space: `df -h`
- Verify output directory permissions
- Check FFmpeg logs for encoding errors

---

## Performance Tuning

### Concurrent Processing
- **Settings → Processing Nodes → Local Server**
- **Max Concurrent Flows:** 3-5 (for 8 vCPU server)
  - Too high: CPU overload, slower overall processing
  - Too low: Underutilized resources, queue backlog

### CRF Quality Settings
Adjust CRF based on use case:
- **Archive/High Quality:** CRF 18-20
- **Web Streaming:** CRF 23-25 (recommended)
- **Mobile/Low Bandwidth:** CRF 26-28

### Resolution Limits
- **4K Content:** Max 3840x2160 (if server can handle)
- **Standard Web:** Max 1920x1080 (recommended)
- **Mobile Optimized:** Max 1280x720

---

## Next Steps

After completing FileFlows configuration:

1. **Task 9:** Read integration documentation (`docs/04-integrations/directus-fileflows.md`)
2. **Task 10:** Run integration tests (`./tests/integration/test-directus-fileflows.sh`)
3. **End-to-End Test:** Upload media to Directus, verify it processes through FileFlows, check updated metadata in Directus

---

## References

- FileFlows Documentation: https://docs.fileflows.com/
- FFmpeg Documentation: https://ffmpeg.org/documentation.html
- H.264 Encoding Guide: https://trac.ffmpeg.org/wiki/Encode/H.264
- Audio Normalization Guide: https://ffmpeg.org/ffmpeg-filters.html#loudnorm
- WebP Encoding Guide: https://developers.google.com/speed/webp/docs/using
