# External APIs

BorgStack services integrate with several external APIs for core functionality. These are APIs **external to the BorgStack deployment** that services connect to over the internet.

## WhatsApp Business API (via Evolution API)

- **Purpose:** Enable WhatsApp messaging capabilities through Evolution API
- **Documentation:** https://developers.facebook.com/docs/whatsapp
- **Base URL(s):** https://graph.facebook.com/v18.0/ (Meta's WhatsApp Cloud API) OR self-hosted WhatsApp Business API
- **Authentication:** Bearer token (access token from Meta Business App)
- **Rate Limits:**
  - Cloud API: 1,000 free conversations/month, then tiered pricing
  - Business messages: 80 messages/second per phone number
  - Marketing messages: Lower rate limits apply

**Key Endpoints Used:**
- `POST /{phone-number-id}/messages` - Send WhatsApp messages (text, media, interactive)
- `GET /{phone-number-id}` - Verify phone number configuration
- `POST /{phone-number-id}/register` - Register phone number with WhatsApp

**Integration Notes:**
- Evolution API abstracts WhatsApp Business API complexity
- Supports both Meta's Cloud API and self-hosted Business API Server
- Requires Meta Business Account, App, and verified phone number
- Webhook configuration required for receiving messages (Evolution API handles this)
- Users must configure WhatsApp API credentials in Evolution API admin panel

---

## Let's Encrypt ACME API (via Caddy)

- **Purpose:** Automatic SSL/TLS certificate issuance and renewal
- **Documentation:** https://letsencrypt.org/docs/
- **Base URL(s):** https://acme-v02.api.letsencrypt.org/directory (production), https://acme-staging-v02.api.letsencrypt.org/directory (staging)
- **Authentication:** ACME protocol with domain validation (HTTP-01 or TLS-ALPN-01 challenge)
- **Rate Limits:**
  - 50 certificates per registered domain per week
  - 5 duplicate certificates per week
  - 300 new orders per account per 3 hours

**Key Endpoints Used:**
- Automatic ACME protocol negotiation (handled by Caddy)
- HTTP-01 challenge: `/.well-known/acme-challenge/` endpoint verification
- Certificate renewal 30 days before expiration

**Integration Notes:**
- Fully automated by Caddy; no manual configuration required
- Requires DNS records pointing to server public IP
- Port 80 must be accessible for HTTP-01 challenge validation
- Port 443 for TLS certificate serving
- Caddy automatically handles certificate storage and renewal
- Staging environment recommended for testing to avoid rate limits

---

## External Storage Providers (via Duplicati)

- **Purpose:** Off-site backup destinations for disaster recovery
- **Documentation:** Varies by provider
- **Base URL(s):** Configured per provider
- **Authentication:** Provider-specific (API keys, OAuth, credentials)
- **Rate Limits:** Provider-specific

**Supported Providers:**
- **AWS S3 / S3-compatible** - `https://{bucket}.s3.{region}.amazonaws.com`
- **Google Cloud Storage** - `https://storage.googleapis.com`
- **Backblaze B2** - `https://api.backblazeb2.com`
- **Azure Blob Storage** - `https://{account}.blob.core.windows.net`
- **FTP/SFTP servers** - Customer-provided
- **WebDAV** - Customer-provided (e.g., Nextcloud, ownCloud)
- **Local/Network drives** - Direct file system access

**Integration Notes:**
- Users configure backup destination in Duplicati web UI
- Recommended: External cloud storage for true disaster recovery
- Encryption keys stored in Duplicati configuration (must be backed up separately)
- Test restoration procedures critical for backup validation
- Consider Brazilian data sovereignty requirements when selecting provider

---

## Optional Email Service (SMTP for Chatwoot/n8n)

- **Purpose:** Email notifications, channel integration, workflow alerts
- **Documentation:** Provider-specific (SendGrid, Mailgun, AWS SES, custom SMTP)
- **Base URL(s):** SMTP server address (e.g., smtp.sendgrid.net:587)
- **Authentication:** SMTP credentials or API keys
- **Rate Limits:** Provider-specific (typically measured in emails/day or emails/month)

**Key Endpoints Used:**
- SMTP protocol for email sending
- Chatwoot: Email channel for customer support tickets
- n8n: Email nodes for workflow notifications

**Integration Notes:**
- Not required for core functionality but recommended for production
- Chatwoot requires SMTP for email inbox functionality
- n8n email nodes optional for workflow notifications
- Consider transactional email providers for reliability (SendGrid, Mailgun, Postmark)
- Brazilian providers: MailerLite, Brevo (formerly Sendinblue) with Brazilian data centers

---
