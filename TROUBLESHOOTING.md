# Troubleshooting & FAQ

Common issues and solutions for the Daily Job Agent system.

---

## 🚨 Common Issues

### 1. n8n Won't Start

**Symptom:** Docker container exits immediately

**Diagnosis:**
```bash
# Check container logs
docker-compose logs n8n

# Check if port is already in use
sudo lsof -i :5678
```

**Solutions:**

**A) Port 5678 is already in use**
```bash
# Kill the process using the port
sudo kill -9 $(lsof -t -i:5678)

# Or change the port in docker-compose.yml
ports:
  - "5679:5678"  # Changed from 5678:5678
```

**B) Missing environment variables**
```bash
# Verify .env file exists and has all required variables
cat .env | grep -E "GEMINI_API_KEY|N8N_ENCRYPTION_KEY"

# If missing, regenerate from template
cp .env.example .env
# Then fill in your values
```

**C) Permission issues**
```bash
# Fix n8n_data directory permissions
sudo chown -R 1000:1000 n8n_data/

# On Linux, you may need to set proper permissions
chmod -R 755 n8n_data/
```

---

### 2. Google Sheets API Not Working

**Symptom:** "Error: Permission denied" or "Service account not authorized"

**Diagnosis:**
```bash
# Check if credentials file exists
ls -la credentials/google-service-account.json

# Verify service account email in .env
cat .env | grep GOOGLE_SERVICE_ACCOUNT_EMAIL
```

**Solutions:**

**A) Credentials file missing**
```
1. Go to Google Cloud Console
2. Navigate to IAM & Admin > Service Accounts
3. Select your service account
4. Keys > Add Key > Create New Key > JSON
5. Save as credentials/google-service-account.json
```

**B) Sheet not shared with service account**
```
1. Open your Google Sheet
2. Click "Share" button
3. Add the service account email (found in JSON file)
4. Give "Editor" permissions
5. Click "Send"
```

**C) Google Sheets API not enabled**
```
1. Go to Google Cloud Console
2. APIs & Services > Library
3. Search "Google Sheets API"
4. Click "Enable"
```

**D) Wrong Sheet ID in .env**
```
# Get Sheet ID from URL:
# https://docs.google.com/spreadsheets/d/SHEET_ID_HERE/edit

# Update .env:
GOOGLE_SHEET_ID=actual-sheet-id-from-url
```

---

### 3. Gemini API Errors

**Symptom:** "API key not valid" or "Resource exhausted"

**Diagnosis:**
```bash
# Test API key directly
curl -X POST \
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=YOUR_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'
```

**Solutions:**

**A) Invalid API key**
```
1. Go to https://makersuite.google.com/app/apikey
2. Verify your API key is active
3. Create a new one if needed
4. Update .env file:
   GEMINI_API_KEY=your-new-key-here
5. Restart container:
   docker-compose restart
```

**B) Rate limit exceeded (429 error)**
```
Daily limit: 1,500 requests
Per minute: 60 requests

Solutions:
1. Add Wait nodes between calls (1-2 seconds)
2. Reduce number of jobs processed per day
3. Create multiple Google accounts with separate API keys
4. Implement exponential backoff in n8n:
   - Settings > Retry On Fail: true
   - Max Retries: 3
   - Wait Between Tries: 5000ms
```

**C) Quota exceeded (Resource exhausted)**
```
You've hit the daily limit (1,500 requests).

Options:
1. Wait until midnight (resets daily)
2. Use multiple API keys (rotate them)
3. Cache results to reduce calls
4. Process fewer jobs per run
```

---

### 4. LinkedIn RSS Feed Not Returning Jobs

**Symptom:** "No jobs found" or empty RSS feed

**Solutions:**

**A) Fix URL encoding**
```javascript
// Ensure spaces and special characters are encoded
Bad:  keywords=Software Development Engineer
Good: keywords=Software%20Development%20Engineer

// Use encodeURIComponent in n8n:
={{encodeURIComponent("Software Development Engineer")}}
```

**B) Verify experience filter**
```
f_E parameter values:
- 1: Internship
- 2: Entry level (0-2 years)  ← Use this
- 3: Associate (2-5 years)
- 4: Mid-Senior (5+ years)
- 5: Director
- 6: Executive
```

**C) Time range too restrictive**
```
f_TPR values:
- r86400: Last 24 hours (may have few results)
- r604800: Last week (recommended)
- r2592000: Last month

Change in n8n URL:
f_TPR=r604800  # Last week instead of 24 hours
```

**D) LinkedIn changed URL structure**
```
Check current working URL format:
1. Go to linkedin.com/jobs
2. Search manually
3. Look at browser URL
4. Extract the pattern
5. Update your RSS URL in n8n
```

---

### 5. SerpAPI Not Working

**Symptom:** "Invalid API key" or "Monthly quota exceeded"

**Diagnosis:**
```bash
# Test SerpAPI key
curl "https://serpapi.com/search?engine=google&q=test&api_key=YOUR_KEY"
```

**Solutions:**

**A) Check account status**
```
1. Login to https://serpapi.com/dashboard
2. Check "API Calls" section
3. Verify you haven't exceeded 100/month
4. Check if account is active
```

**B) Quota exceeded**
```
Free tier: 100 searches/month

Solutions:
1. Wait until next month
2. Use only for critical searches
3. Implement caching in n8n
4. Use LinkedIn RSS as primary source
5. Create additional free accounts (not recommended)
```

**C) Invalid API key**
```
1. Go to https://serpapi.com/manage-api-key
2. Copy the key
3. Update .env:
   SERPAPI_KEY=your-key-here
4. Restart:
   docker-compose restart
```

---

### 6. Resume PDF Not Being Read

**Symptom:** "File not found" or "Cannot read PDF"

**Diagnosis:**
```bash
# Check if file exists and is accessible
ls -la resumes/master-resume.pdf

# Verify it's a valid PDF
file resumes/master-resume.pdf
# Should output: PDF document
```

**Solutions:**

**A) File doesn't exist**
```bash
# Create the directory
mkdir -p resumes

# Copy your resume
cp ~/Downloads/your-resume.pdf resumes/master-resume.pdf

# Verify
ls -la resumes/
```

**B) Permission denied**
```bash
# Fix permissions
chmod 644 resumes/master-resume.pdf
```

**C) Corrupted PDF**
```bash
# Test PDF validity
pdfinfo resumes/master-resume.pdf

# If corrupted, re-export from source
# Or use online PDF repair tool
```

**D) Volume mount issue**
```bash
# Check if volume is mounted correctly
docker-compose exec n8n ls -la /resumes

# If empty, check docker-compose.yml:
volumes:
  - ./resumes:/resumes:ro  # Should be present
```

---

### 7. Workflow Not Running on Schedule

**Symptom:** Manual execution works, but scheduled execution doesn't run

**Solutions:**

**A) Timezone mismatch**
```
Check n8n timezone:
- Environment > GENERIC_TIMEZONE=Asia/Kolkata

Verify in workflow:
- Schedule Trigger node
- Timezone: Asia/Kolkata
- Time: 09:00 (9 AM IST)
```

**B) Workflow not activated**
```
In n8n UI:
1. Open your workflow
2. Top-right corner: Toggle should be GREEN "Active"
3. If gray, click to activate
```

**C) Container restarted**
```bash
# Check container uptime
docker ps

# If recently restarted, workflows are deactivated
# Re-activate in n8n UI
```

**D) Execution mode**
```
Check n8n settings:
- Executions should be "main process" (default)
- Not "queue mode" (requires additional setup)
```

---

### 8. High Memory Usage / Container Crashes

**Symptom:** n8n container uses too much RAM or crashes

**Solutions:**

**A) Limit Docker memory**
```yaml
# In docker-compose.yml, add:
services:
  n8n:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

**B) Process fewer jobs**
```javascript
// In Filter & Deduplicate node
return allJobs.slice(0, 10).map(job => ({ json: job }));
// Reduced from 20 to 10
```

**C) Increase timeout settings**
```yaml
# In docker-compose.yml
environment:
  - EXECUTIONS_TIMEOUT=1800  # Reduced from 3600
  - N8N_PAYLOAD_SIZE_MAX=8   # Reduced from 16
```

**D) Clear old execution data**
```bash
# Access n8n container
docker-compose exec n8n sh

# Clear old executions (older than 7 days)
# Settings > Executions > Delete old executions
```

---

## ❓ Frequently Asked Questions

### Q1: Can I run this on a Raspberry Pi?

**A:** Yes! But with limitations:
```
Requirements:
- Raspberry Pi 4 (4GB RAM minimum)
- 32GB+ SD card
- Docker installed

Performance:
- May be slower than a laptop
- Limit to 10 jobs/day
- Increase timeout values
- Avoid running other heavy services
```

### Q2: How do I add more job boards?

**A:** 
```
1. Add new HTTP Request node or RSS Read node
2. Connect to the Merge node (after Job Search Module)
3. Ensure output format matches other sources:
   {
     title: "",
     company: "",
     location: "",
     url: "",
     description: "",
     salary: ""
   }
4. Test with manual execution
5. Adjust deduplication logic if needed
```

### Q3: Can I use Claude API instead of Gemini?

**A:**
```
⚠️ Not recommended for free tier:

Claude API pricing (as of 2024):
- Claude Sonnet: $3 per million tokens
- Claude Haiku: $0.80 per million tokens

For 60 jobs/day × 30 days = 1,800 jobs/month
Cost: ~$30-50/month

Gemini is FREE (1,500 requests/day)

However, if you want to use Claude:
1. Get API key from console.anthropic.com
2. Replace Gemini HTTP Request node
3. Update prompt format
4. Monitor costs carefully
```

### Q4: How do I backup my data?

**A:**
```bash
# Backup script
#!/bin/bash
BACKUP_DIR="backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup n8n data
cp -r n8n_data "$BACKUP_DIR/"

# Backup .env (encrypted)
gpg -c .env -o "$BACKUP_DIR/.env.gpg"

# Backup workflows
cp -r workflows "$BACKUP_DIR/"

# Export Google Sheet as CSV (manual)
echo "Don't forget to export Google Sheet!"

# Compress
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup saved to $BACKUP_DIR.tar.gz"
```

### Q5: How do I update n8n to the latest version?

**A:**
```bash
# Pull latest n8n image
docker-compose pull

# Restart with new image
docker-compose down
docker-compose up -d

# Verify version
docker-compose exec n8n n8n --version
```

### Q6: Can I run multiple instances for different job types?

**A:**
```
Yes! Clone the project:

1. Copy entire directory:
   cp -r job-agent-setup job-agent-frontend

2. Update docker-compose.yml:
   - Change container name
   - Change port (5678 → 5679)
   - Update .env with different parameters

3. Customize search keywords:
   JOB_KEYWORDS=Frontend,React,Vue,Angular

4. Start:
   cd job-agent-frontend
   docker-compose up -d
```

### Q7: How do I handle "Cannot find module" errors in Code nodes?

**A:**
```
n8n includes these libraries by default:
- lodash
- moment
- axios
- cheerio
- pdf-parse

If you need others:
1. Use HTTP Request instead of custom code
2. Or install in Docker container:
   docker-compose exec n8n npm install -g YOUR_PACKAGE
   
⚠️ Custom packages are lost on container restart
   Better: Use native n8n nodes when possible
```

### Q8: How do I test a single job without running the full workflow?

**A:**
```
1. In n8n, click "Execute Workflow"
2. Add a "Filter" node before "Loop Through Jobs":
   - Condition: {{$json.company}} equals "Google"
3. This processes only Google jobs
4. Remove filter when done testing

Or:

1. Use "Execute Node" (click on specific node)
2. Provide manual input data
3. Test each node individually
```

### Q9: Can I get notified when jobs are found?

**A:**
```
Add at the end of workflow:

Method 1: Email (using Gmail)
- Node: Gmail > Send Email
- To: your-email@gmail.com
- Subject: "{{$json.newJobs}} New Jobs Found!"
- Body: Daily summary

Method 2: Telegram (FREE)
- Create Telegram bot via @BotFather
- Node: Telegram > Send Message
- Message: Job summary

Method 3: Discord Webhook (FREE)
- Create webhook in Discord server
- Node: HTTP Request
- POST to webhook URL with job data
```

### Q10: How do I stop the workflow from running?

**A:**
```
Temporary:
1. Open workflow in n8n
2. Click toggle at top-right (make it gray/inactive)

Permanent:
docker-compose down

Just for today:
1. Activate workflow
2. It will skip until next scheduled time
```

---

## 🔧 Advanced Troubleshooting

### Enable Debug Mode

```yaml
# In docker-compose.yml
environment:
  - N8N_LOG_LEVEL=debug
```

```bash
# Restart and check logs
docker-compose restart
docker-compose logs -f n8n
```

### Test Individual Components

```bash
# Test Gemini API
curl -X POST \
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=YOUR_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"Say hello"}]}]}'

# Test Google Sheets API
# (requires OAuth2 token, easier to test in n8n)

# Test SerpAPI
curl "https://serpapi.com/search?engine=google&q=test&api_key=YOUR_KEY"
```

### Reset Everything

```bash
# Nuclear option: start fresh
docker-compose down -v
rm -rf n8n_data/
docker-compose up -d

# Then re-import your workflow from workflows/
```

---

## 📞 Getting Help

If you're still stuck:

1. **Check n8n Community:** https://community.n8n.io/
2. **Search GitHub Issues:** https://github.com/n8n-io/n8n/issues
3. **Review Logs:** `docker-compose logs -f n8n`
4. **Export Workflow:** Share JSON (remove sensitive data) for debugging
5. **n8n Documentation:** https://docs.n8n.io/

---

## 🎯 Performance Optimization

### Reduce API Calls

```javascript
// Cache job URLs in Google Sheets
// Add a "Processed Jobs" sheet with columns: URL, Date

// In workflow, check before processing:
const processedJobs = await sheets.getValues('Processed Jobs!A:B');
const processedUrls = new Set(processedJobs.map(row => row[0]));

if (processedUrls.has(currentJob.url)) {
  return null; // Skip this job
}
```

### Speed Up Execution

```javascript
// Use parallel processing for independent tasks
// Instead of sequential:
Job 1 → Resume → Recruiter → Log
Job 2 → Resume → Recruiter → Log

// Use parallel:
Job 1 → Resume ┐
Job 2 → Resume ├→ Log All
Job 3 → Resume ┘
```

### Monitor Performance

```javascript
// Add timing nodes
const startTime = Date.now();

// ... your workflow ...

const endTime = Date.now();
const duration = (endTime - startTime) / 1000;

console.log(`Processed in ${duration} seconds`);
```

---

Remember: Most issues are configuration-related. Double-check your .env file and API credentials first!
