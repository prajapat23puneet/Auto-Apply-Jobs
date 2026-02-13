# Troubleshooting & FAQ

Common issues and solutions for the Daily Job Agent system.

---

## 🚨 Common Issues

### 0. LinkedIn RSS Parsing Error

**Symptom:** `Attribute without value Line: 14 Column: 427 Char: d`

**Problem:** LinkedIn returns malformed HTML that breaks the RSS Feed Read node.

**Solution (ALREADY FIXED in latest workflow):**

The workflow now uses HTTP Request + custom HTML parser instead of RSS Feed Read.

**To apply:**
1. Delete old workflow
2. Re-import `workflows/daily-job-agent-importable.json`

**See detailed fix:** `FIX_LINKEDIN_RSS_ERROR.md`

---

## 🐛 Troubleshooting

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

**Symptom:** "File not found" or "Cannot read PDF" or "Access to the file is not allowed"

**Diagnosis:**
```bash
# Check if file exists and is accessible
ls -la resumes/master-resume.pdf

# Verify it's a valid PDF
file resumes/master-resume.pdf
# Should output: PDF document

# Check inside container
docker-compose exec n8n ls -la /home/node/.n8n-files/resumes/
```

**Solutions:**

**A) File Access Error (Most Common)**
```
Error: Access to the file is not allowed. Allowed paths: /home/node/.n8n-files
```

**Fix:** The file path must be inside n8n's allowed directory.

1. **Check docker-compose.yml has correct volume mount:**
   ```yaml
   volumes:
     - ./resumes:/home/node/.n8n-files/resumes:ro
   ```

2. **Update workflow file path to:**
   ```
   /home/node/.n8n-files/resumes/master-resume.pdf
   ```

3. **Restart n8n:**
   ```bash
   docker-compose restart
   ```

**See detailed fix guide:** `FIX_FILE_ACCESS_ERROR.md`

**B) File doesn't exist**
```bash
# Create the directory
mkdir -p resumes

# Copy your resume
cp ~/Downloads/your-resume.pdf resumes/master-resume.pdf

# Verify
ls -la resumes/
```

**B) File doesn't exist**
```bash
# Create the directory
mkdir -p resumes

# Copy your resume
cp ~/Documents/your-resume.pdf resumes/master-resume.pdf

# Verify
ls -la resumes/
```

**C) Permission denied**
```bash
# Fix permissions
chmod 644 resumes/master-resume.pdf
```

**C) Permission denied**
```bash
# Fix permissions
chmod 644 resumes/master-resume.pdf

# Restart container
docker-compose restart
```

**D) Corrupted PDF**
```bash
# Test PDF validity
pdfinfo resumes/master-resume.pdf

# If corrupted, re-export from source
# Or use online PDF repair tool
```

**D) Corrupted PDF**
```bash
# Test PDF validity
pdfinfo resumes/master-resume.pdf

# If corrupted, re-export from source
# Or use online PDF repair tool
```

**E) Volume mount issue**
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
# 🔧 Quick Fix: LinkedIn Response Format Error

## Problem
```
Response body is not valid JSON. Change "Response Format" to "String"
```

OR

```
Attribute without value Line: 14 Column: 427 Char: d
```

These errors occur when LinkedIn returns HTML instead of JSON, or malformed HTML/XML.

## ✅ Solution

The issue is **ALREADY FIXED** in the latest workflow JSON file.

### What Was Changed:

**1. Response Format Set to String:**

```json
{
  "options": {
    "response": {
      "response": {
        "neverError": true,
        "fullResponse": false,
        "responseFormat": "string"  // Changed from default "json"
      }
    }
  }
}
```

**2. Improved HTML Parser:**

The parser now handles multiple response formats:
- `$input.item.json.data`
- `$input.item.json.body`
- `$input.item.json.response`
- `$input.item.json` (direct string)

---

## 🚀 How to Apply the Fix

### If you haven't imported the workflow yet:
You're good! Just import `workflows/daily-job-agent-importable.json` normally.

### If you already have the workflow:

**Option 1: Re-import (Easiest)**
```bash
# In n8n:
1. Delete the old workflow
2. Import workflows/daily-job-agent-importable.json
3. Reconfigure Google Sheets credential
4. Test
```

**Option 2: Manual Fix (Keep your settings)**

1. **Delete the "LinkedIn Jobs RSS" node** (if it exists)

2. **Add new "HTTP Request" node:**
   - Name: `LinkedIn Jobs (HTTP)`
   - Method: GET
   - URL: 
   ```
   https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords={{ encodeURIComponent($node['Initialize Variables'].json['keywords']) }}&location={{ encodeURIComponent($node['Initialize Variables'].json['location']) }}&f_E=2&f_TPR=r604800&start=0
   ```
   - **IMPORTANT:** Options → Response → Response Format: `String` (not JSON!)
   - Options → Response → Never Error: `true`
   - Options → Response → Full Response: `false`

3. **Add "Code" node after it:**
   - Name: `Parse LinkedIn HTML`
   - Copy the JavaScript code from the workflow JSON file
   - Look for the node with id: `linkedin-parse`

4. **Connect the nodes:**
   ```
   Extract Resume Text (Once) 
     → LinkedIn Jobs (HTTP) 
     → Parse LinkedIn HTML 
     → Merge Job Sources
   ```

5. **Save and test**

---

## 🎯 Why This Happens

LinkedIn's job search endpoint sometimes returns:
- Malformed HTML attributes (missing quotes)
- Incomplete attribute values
- Invalid XML/HTML structure

The RSS Feed Read node uses strict XML parsing which fails on these issues.

Our solution:
- ✅ Uses HTTP Request (gets raw HTML)
- ✅ Custom Cheerio parser (more forgiving)
- ✅ Error handling (workflow continues on failure)
- ✅ Fallback parsing logic (tries multiple selectors)

---

## ✅ Verification

After applying the fix:

1. **Test the LinkedIn nodes:**
   - Click on "LinkedIn Jobs (HTTP)" node
   - Click "Execute Node"
   - Should return raw HTML

2. **Test the parser:**
   - Click on "Parse LinkedIn HTML" node
   - Click "Execute Node"
   - Should return structured job data

3. **Check output:**
   ```json
   {
     "title": "Software Development Engineer",
     "company": "Company Name",
     "location": "India",
     "url": "https://linkedin.com/...",
     "source": "LinkedIn"
   }
   ```

---

## 🔍 Alternative Solutions

### Option A: Use Different LinkedIn URL

Try the LinkedIn API endpoint directly:
```
https://www.linkedin.com/jobs/api/seeMoreJobPostings/search
```

### Option B: Use LinkedIn RSS (if they fix it)

If LinkedIn fixes their HTML, you can switch back to RSS:
```xml
https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=...&f_TPR=r604800
```

### Option C: Skip LinkedIn (use alternatives)

If LinkedIn keeps failing:
1. Rely on SerpAPI (Google Jobs)
2. Use Naukri.com
3. Add Indeed RSS feed
4. Add other job boards

---

## 🐛 Still Getting Errors?

### Error: "No jobs found"

**Possible causes:**
1. LinkedIn changed their HTML structure
2. No jobs match your criteria
3. LinkedIn is rate-limiting

**Debug:**
```javascript
// In "Parse LinkedIn HTML" node, add console.log:
console.log('HTML length:', html.length);
console.log('First 500 chars:', html.substring(0, 500));
```

### Error: "Cheerio is not defined"

Cheerio should be available in n8n by default. If not:
- Restart n8n container: `docker-compose restart`
- Check n8n version: Update to latest

### Error: "Cannot read property 'json'"

The HTTP request might be returning different format. Update:
```javascript
const html = $input.item.json.data || 
             $input.item.json.body || 
             $input.item.json.response || 
             '';
```

---

## 💡 Pro Tips

### 1. Fallback Job Sources

Don't rely only on LinkedIn. The workflow has:
- ✅ Google Jobs (SerpAPI) - More reliable
- ✅ Naukri.com - India-focused
- ✅ Easy to add more sources

### 2. Monitor Execution Logs

```bash
# Check n8n logs for LinkedIn errors
docker-compose logs -f n8n | grep -i linkedin
```

### 3. Test Individual Nodes

Always test nodes individually before running full workflow:
- Click node → Execute Node → Check output

### 4. Update Workflow Regularly

LinkedIn changes their HTML frequently. Check for workflow updates.

---

## 📚 Related Documentation

- n8n HTTP Request: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/
- Cheerio Documentation: https://cheerio.js.org/
- LinkedIn Job Search API: (Unofficial, subject to change)

---

## 🎉 Success Indicators

After fix is applied:

- ✅ "LinkedIn Jobs (HTTP)" returns HTML (not error)
- ✅ "Parse LinkedIn HTML" returns job objects
- ✅ Workflow continues even if LinkedIn fails
- ✅ Google Sheet shows jobs from all sources

---

**This fix is already applied in the latest workflow file!** 🚀

Just re-import `workflows/daily-job-agent-importable.json` and you're good to go!
---

# 🔧 Quick Fix: Cheerio Module Disallowed Error

## Problem
```
Module 'cheerio' is disallowed [line 2]
```

This error occurs in the "Parse LinkedIn HTML" or "Parse Naukri Job Data" nodes when trying to use the Cheerio library.

## ✅ Solution

The issue is **ALREADY FIXED** in the latest workflow JSON file.

### What Was Wrong:

**Before (❌ Used Cheerio - Not allowed in n8n):**
```javascript
const cheerio = require('cheerio');  // ❌ DISALLOWED
const $ = cheerio.load(html);
$('.title').text();  // Won't work
```

### What Was Changed:

**After (✅ Uses Regex - Built-in JavaScript):**
```javascript
// No external libraries needed!
const titleMatch = html.match(/class="[^"]*title[^"]*"[^>]*>([^<]+)</i);
const title = titleMatch ? titleMatch[1].trim() : '';
```

---

## 🏗️ New Architecture

### LinkedIn Jobs Processing:

**1. HTTP Request** → **2. HTML Extract** → **3. Regex Parser**

```
LinkedIn Jobs (HTTP)
  ↓ (Returns full HTML as string)
Extract LinkedIn Job Cards (HTML node)
  ↓ (Extracts <li> elements as array)
Parse LinkedIn Jobs (Code node with regex)
  ↓ (Structured job data)
Merge Job Sources
```

### Naukri Jobs Processing:

**1. HTTP Request** → **2. HTML Extract** → **3. Regex Parser**

```
Naukri.com Scrape
  ↓ (Returns full HTML)
Extract Naukri Jobs (HTML node)
  ↓ (Extracts <article> elements)
Parse Naukri Job Data (Code node with regex)
  ↓ (Structured job data)
Merge Job Sources
```

---

## 🚀 How to Apply the Fix

### If you haven't imported the workflow yet:
You're good! Just import `workflows/daily-job-agent-importable.json` normally.

### If you already have the workflow:

**Option 1: Re-import (Recommended)**
```bash
# In n8n UI:
1. Delete the old workflow
2. Import workflows/daily-job-agent-importable.json
3. Reconfigure Google Sheets credential
4. Test each job source node
5. Done!
```

**Option 2: Manual Fix**

For **LinkedIn**:

1. Keep "LinkedIn Jobs (HTTP)" as is

2. Add **"HTML Extract" node** after it:
   - Name: `Extract LinkedIn Job Cards`
   - Data Property Name: `data`
   - Extraction Values:
     - Key: `jobs`
     - CSS Selector: `li`
     - Return Array: `true`
     - Return Value: `html`

3. Replace the Code node with regex-based parsing:
   - Copy the JavaScript from the workflow JSON
   - Look for node id: `linkedin-parse`

4. Connect: `LinkedIn Jobs (HTTP)` → `Extract LinkedIn Job Cards` → `Parse LinkedIn Jobs` → `Merge Job Sources`

For **Naukri**:

1. Keep "Naukri.com Scrape" and "Extract Naukri Jobs" as is

2. Update "Parse Naukri Job Data" code:
   - Remove `const cheerio = require('cheerio');`
   - Replace with regex-based parsing from the workflow JSON

---

## 🎯 Why This Happened

### n8n Security Restrictions

n8n **blocks** external modules in Code nodes for security:
- ❌ `require('cheerio')` - Blocked
- ❌ `require('axios')` - Blocked
- ❌ `require('lodash')` - Blocked
- ✅ Built-in JavaScript - Allowed
- ✅ `require('crypto')` - Allowed (built-in)

### Why Cheerio Was Used Initially

Cheerio is great for HTML parsing in Node.js:
```javascript
$('.title').text()  // Easy and clean
```

But it's not available in n8n's Code nodes.

### Our Solution

**Use n8n's built-in HTML node + Regex:**

1. **HTML Extract node** - Extracts elements using CSS selectors
2. **Code node with regex** - Parses the extracted HTML

This combination is:
- ✅ Allowed by n8n
- ✅ No external dependencies
- ✅ Works reliably
- ✅ Fast enough for our needs

---

## 📋 Regex Pattern Examples

Our solution uses regex to extract data from HTML:

### Extract Title:
```javascript
const titleMatch = html.match(/<h3[^>]*class="[^"]*title[^"]*"[^>]*>([^<]+)<\/h3>/i);
const title = titleMatch ? titleMatch[1].trim() : '';
```

### Extract URL:
```javascript
const urlMatch = html.match(/href="(https:\/\/[^"]*linkedin\.com\/jobs[^"]*)"/i);
const url = urlMatch ? urlMatch[1] : '';
```

### Extract Company:
```javascript
const companyMatch = html.match(/<h4[^>]*>([^<]+)<\/h4>/i);
const company = companyMatch ? companyMatch[1].trim() : 'Unknown';
```

### Clean HTML Entities:
```javascript
const cleanText = text
  .replace(/&amp;/g, '&')
  .replace(/&lt;/g, '<')
  .replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"')
  .replace(/&#39;/g, "'")
  .replace(/\s+/g, ' ')
  .trim();
```

---

## ✅ Verification

After applying the fix, test each node:

### Test 1: LinkedIn HTTP Request
```bash
Execute "LinkedIn Jobs (HTTP)"
✅ Should return HTML string (not error)
```

### Test 2: Extract LinkedIn Job Cards
```bash
Execute "Extract LinkedIn Job Cards"
✅ Should return array of HTML strings (job cards)
```

### Test 3: Parse LinkedIn Jobs
```bash
Execute "Parse LinkedIn Jobs"
✅ Should return structured job objects:
[
  {
    "title": "Software Engineer",
    "company": "Company Name",
    "url": "https://...",
    "source": "LinkedIn"
  }
]
```

### Test 4: Full Workflow
```bash
Execute entire workflow
✅ Google Sheet should populate with jobs from all sources
```

---

## 🐛 Troubleshooting

### No jobs extracted

**Possible causes:**
1. LinkedIn/Naukri changed their HTML structure
2. CSS selectors don't match
3. No jobs available for your criteria

**Debug:**
```javascript
// Add to Parse node:
console.log('HTML cards found:', jobsHtml.length);
console.log('First card preview:', jobsHtml[0]?.substring(0, 200));
```

### Regex not matching

**Update the regex patterns:**

LinkedIn changes their class names frequently. You may need to:
1. View page source of LinkedIn jobs page
2. Identify new class names
3. Update regex patterns in the Code node

Example:
```javascript
// If LinkedIn now uses 'job-card-title' instead of 'title':
const titleMatch = html.match(/class="[^"]*job-card-title[^"]*"[^>]*>([^<]+)</i);
```

### Still getting cheerio error

**Check you're using the latest workflow:**
```bash
# Verify workflow version
grep -i "cheerio" workflows/daily-job-agent-importable.json

# Should return: (empty - no matches)
```

If you see "cheerio" in the file, re-download the latest version.

---

## 💡 Alternative: Use n8n's Built-in Nodes

If regex seems complex, you can use n8n's native nodes:

### Option A: Multiple HTML Extract Nodes
```
HTML Extract (get titles) ─┐
HTML Extract (get companies) ├─→ Merge → Code (combine)
HTML Extract (get URLs) ─────┘
```

### Option B: Set Multiple Values Node
After HTML Extract, use "Set" node to restructure data.

---

## 📚 Allowed Modules in n8n

What **IS** allowed in n8n Code nodes:

### Built-in Node.js Modules:
- ✅ `crypto` - Encryption/hashing
- ✅ `url` - URL parsing
- ✅ `querystring` - Query string parsing
- ✅ `buffer` - Binary data
- ✅ `util` - Utilities

### JavaScript Built-ins:
- ✅ `Date`, `Array`, `Object`, `String`, `Number`
- ✅ `Math`, `RegExp`, `JSON`
- ✅ `Promise`, `async/await`
- ✅ `Map`, `Set`, `WeakMap`, `WeakSet`

### What's NOT Allowed:
- ❌ `cheerio` (HTML parsing)
- ❌ `axios` (HTTP requests - use HTTP Request node)
- ❌ `lodash` (utilities - use native JS)
- ❌ `moment` (dates - use native Date)
- ❌ Most npm packages

---

## 🎉 Benefits of the Fix

- ✅ **No dependencies** - Pure JavaScript
- ✅ **Faster** - No library overhead
- ✅ **More reliable** - No external package issues
- ✅ **Compliant** - Works within n8n's restrictions
- ✅ **Maintainable** - Easy to update regex patterns

---

## 📖 Learn More

- **n8n Code Node:** https://docs.n8n.io/code-examples/methods-variables-examples/
- **JavaScript Regex:** https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions
- **HTML Parsing with Regex:** When to use and when to avoid

---

**This fix is already applied in the latest workflow!** 🚀

Just re-import `workflows/daily-job-agent-importable.json` and you're good to go!

---

## 🎯 Summary

| Issue | Solution |
|-------|----------|
| Cheerio not allowed | Use regex + HTML Extract node |
| Complex HTML parsing | Split into HTML Extract → Code |
| Multiple dependencies | Pure JavaScript, no imports |
| Maintenance | Easy to update regex patterns |

The new approach is **simpler, faster, and fully compliant** with n8n! 🎊

# 🔧 Quick Fix: Access to ENV Vars Denied

## Problem
```
access to env vars denied
```

This error occurs in nodes that try to access `$env.VARIABLE_NAME` directly in expression fields.

## ✅ Solution

The issue is **ALREADY FIXED** in the latest workflow JSON file.

### What Was Wrong:

**Before (❌ Direct $env access in expressions):**
```javascript
// In node parameters:
"api_key": "={{ $env.SERPAPI_KEY }}"  // ❌ Denied
"url": "...?key={{ $env.GEMINI_API_KEY }}"  // ❌ Denied
"documentId": "={{ $env.GOOGLE_SHEET_ID }}"  // ❌ Denied
```

### What Changed:

**After (✅ Access via Initialize Variables node):**
```javascript
// Step 1: Initialize Variables reads $env (allowed at start)
{
  "geminiApiKey": "={{ $env.GEMINI_API_KEY }}",  // ✅ Works here
  "serpApiKey": "={{ $env.SERPAPI_KEY }}",
  "googleSheetId": "={{ $env.GOOGLE_SHEET_ID }}"
}

// Step 2: Other nodes reference Initialize Variables
"api_key": "={{ $('Initialize Variables').item.json.serpApiKey }}"  // ✅ Works
```

---

## 🏗️ How It Works

### The Pattern:

```
Schedule Trigger
  ↓
Initialize Variables (reads ALL $env variables ONCE)
  ↓  ↓  ↓
Other nodes reference Initialize Variables (not $env)
```

### Why This Works:

1. **$env access is restricted** in most node parameter expressions for security
2. **Initialize Variables** runs first and CAN read $env
3. **All other nodes** get values from Initialize Variables via `$('Initialize Variables').item.json.variableName`

---

## 🚀 How to Apply the Fix

### If you haven't imported the workflow yet:
You're good! Just import `workflows/daily-job-agent-importable.json` normally.

### If you already have the workflow:

**Option 1: Re-import (Easiest)**
```bash
# In n8n:
1. Delete the old workflow
2. Import workflows/daily-job-agent-importable.json
3. The Initialize Variables node will have all API keys
4. Other nodes will reference it correctly
5. Done!
```

**Option 2: Manual Fix**

**Step 1: Update "Initialize Variables" node**

Add these to the Set node values:
```json
{
  "name": "geminiApiKey",
  "value": "={{ $env.GEMINI_API_KEY || '' }}"
},
{
  "name": "serpApiKey",
  "value": "={{ $env.SERPAPI_KEY || '' }}"
},
{
  "name": "googleSheetId",
  "value": "={{ $env.GOOGLE_SHEET_ID || '' }}"
}
```

**Step 2: Update "Google Jobs (SerpAPI)" node**

Change the `api_key` parameter from:
```javascript
"={{ $env.SERPAPI_KEY }}"  // ❌ Old
```

To:
```javascript
"={{ $('Initialize Variables').item.json.serpApiKey || '' }}"  // ✅ New
```

**Step 3: Update "Gemini: Analyze Job Match" node**

Change the URL from:
```javascript
"...?key={{ $env.GEMINI_API_KEY }}"  // ❌ Old
```

To:
```javascript
"...?key={{ $('Initialize Variables').item.json.geminiApiKey }}"  // ✅ New
```

**Step 4: Update "Log to Google Sheets" node**

Change documentId value from:
```javascript
"{{ $env.GOOGLE_SHEET_ID }}"  // ❌ Old
```

To:
```javascript
"{{ $('Initialize Variables').item.json.googleSheetId }}"  // ✅ New
```

**Step 5: Update "Extract Recruiter with AI" node**

In the Code node, change:
```javascript
const geminiUrl = `...?key=${$env.GEMINI_API_KEY}`;  // ❌ Old
```

To:
```javascript
const geminiApiKey = $('Initialize Variables').item.json.geminiApiKey;
const geminiUrl = `...?key=${geminiApiKey}`;  // ✅ New
```

---

## 📋 Complete Variable Reference

### Environment Variables (in .env):
```bash
GEMINI_API_KEY=your-key-here
SERPAPI_KEY=your-key-here
GOOGLE_SHEET_ID=your-sheet-id
JOB_ROLE=Software Development Engineer
JOB_EXPERIENCE=1.5
JOB_SALARY_MIN=12
JOB_SALARY_MAX=15
JOB_LOCATION=India
JOB_KEYWORDS=SDE,Full Stack,React
```

### Initialize Variables Output:
```json
{
  "jobRole": "Software Development Engineer",
  "experience": "1.5",
  "salaryMin": "12",
  "salaryMax": "15",
  "location": "India",
  "keywords": "SDE,Full Stack,React",
  "today": "2026-01-16",
  "timestamp": "2026-01-16T10:30:00Z",
  "geminiApiKey": "AIza...",
  "serpApiKey": "abc123...",
  "googleSheetId": "1ABC..."
}
```

### How to Reference in Other Nodes:
```javascript
// Job search parameters
$('Initialize Variables').item.json.jobRole
$('Initialize Variables').item.json.location
$('Initialize Variables').item.json.keywords

// API keys
$('Initialize Variables').item.json.geminiApiKey
$('Initialize Variables').item.json.serpApiKey
$('Initialize Variables').item.json.googleSheetId

// Alternative shorter syntax (if node name is clear):
$node['Initialize Variables'].json.jobRole
```

---

## 🎯 Why $env Access is Restricted

### Security Reasons:

n8n restricts `$env` access in expressions to prevent:
- ❌ Accidental exposure of secrets in logs
- ❌ Security vulnerabilities in shared workflows
- ❌ Credential leaks in error messages
- ❌ Unauthorized access to sensitive data

### Where $env WORKS:
- ✅ Initialize Variables node (at workflow start)
- ✅ Docker environment variables passed to container
- ✅ Some trigger nodes

### Where $env DOESN'T WORK:
- ❌ HTTP Request URL parameters
- ❌ Code node expressions
- ❌ Google Sheets documentId
- ❌ Most node parameter expressions

---

## ✅ Verification

After applying the fix:

### Test 1: Initialize Variables
```bash
Execute "Initialize Variables" node
✅ Should output all variables including API keys
```

### Test 2: Google Jobs (SerpAPI)
```bash
Execute "Google Jobs (SerpAPI)" node
✅ Should make request with API key (check URL in logs)
✅ OR skip gracefully if key is empty
```

### Test 3: Gemini Analysis
```bash
Execute "Gemini: Analyze Job Match" node
✅ Should call Gemini API successfully
✅ Should return ATS score and analysis
```

### Test 4: Google Sheets
```bash
Execute "Log to Google Sheets" node
✅ Should append row to correct sheet
✅ Should use Sheet ID from Initialize Variables
```

---

## 🐛 Troubleshooting

### "Initialize Variables output is empty"

**Check:**
```bash
# Verify .env file exists and is loaded
docker-compose exec n8n env | grep GEMINI_API_KEY

# If empty, restart container
docker-compose restart
```

### "Cannot read property 'json' of undefined"

**Issue:** Initialize Variables node name changed

**Fix:**
```javascript
// Make sure node is named exactly:
"Initialize Variables"

// Not:
"Init Variables"  // ❌
"Setup Variables"  // ❌
```

### "API key is empty/undefined"

**Check Initialize Variables output:**
```javascript
// Should see:
{
  "geminiApiKey": "AIza...",  // ✅ Has value
  "serpApiKey": "",           // ⚠️  Empty but OK if optional
  "googleSheetId": "1ABC..."  // ✅ Has value
}
```

**If all empty:**
- Check .env file has the variables
- Restart Docker: `docker-compose restart`
- Check docker-compose.yml passes environment variables

### "Variables work in test but not in schedule"

**Issue:** Environment variables not persisted

**Fix:**
```bash
# Ensure .env is in the same directory as docker-compose.yml
ls -la .env

# Verify docker-compose.yml has env_file or environment section
grep -A 5 "environment:" docker-compose.yml

# Restart to reload environment
docker-compose down && docker-compose up -d
```

---

## 💡 Best Practices

### 1. Always Use Initialize Variables

```javascript
// ❌ Bad: Direct $env access everywhere
"url": "...?key={{ $env.API_KEY }}"

// ✅ Good: Read once, reference many times
Initialize Variables: "apiKey": "={{ $env.API_KEY }}"
Other nodes: "url": "...?key={{ $('Initialize Variables').item.json.apiKey }}"
```

### 2. Provide Fallback Values

```javascript
// ✅ Good: Won't break if variable is missing
"={{ $env.API_KEY || '' }}"
"={{ $env.SHEET_ID || 'default-sheet-id' }}"
```

### 3. Use Consistent Naming

```javascript
// Environment variable (.env)
GEMINI_API_KEY=...

// Initialize Variables (camelCase)
geminiApiKey

// Reference in nodes
$('Initialize Variables').item.json.geminiApiKey
```

### 4. Document Required vs Optional

```javascript
// In Initialize Variables node notes:
// REQUIRED: geminiApiKey, googleSheetId
// OPTIONAL: serpApiKey (workflow continues without it)
```

---

## 📚 Related Documentation

- **n8n Environment Variables:** https://docs.n8n.io/hosting/environment-variables/
- **n8n Expressions:** https://docs.n8n.io/code-examples/expressions/
- **Node References:** https://docs.n8n.io/code-examples/expressions/data-structure/

---

## 🎉 Benefits of This Approach

| Aspect | Before | After |
|--------|--------|-------|
| Security | ❌ $env exposed in many places | ✅ Centralized in one node |
| Debugging | ❌ Hard to track where variables used | ✅ Single source of truth |
| Maintenance | ❌ Update in multiple nodes | ✅ Update in one place |
| Testing | ❌ Can't easily override values | ✅ Can modify Initialize Variables |
| Sharing | ❌ Credentials in workflow | ✅ Clean workflow, secrets in .env |

---

**This fix is already applied in the latest workflow!** 🚀

Just re-import `workflows/daily-job-agent-importable.json` and all env vars will work correctly!

Remember: Most issues are configuration-related. Double-check your .env file and API credentials first!