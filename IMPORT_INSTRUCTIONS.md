# How to Import the n8n Workflow

This guide shows you how to import the ready-to-use workflow into n8n.

## 📥 Two Import Methods

### Method 1: Import via n8n UI (Recommended)

1. **Start n8n:**
   ```bash
   docker-compose up -d
   ```

2. **Access n8n:**
   - Open browser: http://localhost:5678
   - Login with credentials from `.env`:
     - Username: `admin` (default)
     - Password: `changeme` (default - CHANGE THIS!)

3. **Import the workflow:**
   - Click **"Workflows"** in the top left
   - Click **"Add workflow"** dropdown → **"Import from File"**
   - Select: `workflows/daily-job-agent-importable.json`
   - Click **"Import"**

4. **Workflow imported!** ✅

---

### Method 2: Import via URL (Alternative)

1. In n8n, click **"Add workflow"** → **"Import from URL"**
2. If you've pushed to GitHub, use the raw file URL
3. Click **"Import"**

---

## 🔧 Post-Import Configuration

### Step 1: Configure Google Sheets Credential

The workflow needs to connect to your Google Sheet.

**Option A: Service Account (Recommended - No OAuth needed)**

1. Click on the **"Log to Google Sheets"** node
2. Under **"Credential to connect with"**, click dropdown
3. Click **"Create New Credential"**
4. Select **"Google Service Account"**
5. Click **"Upload Service Account JSON"**
6. Select: `credentials/google-service-account.json`
7. Click **"Save"**

**Option B: OAuth2 (Alternative)**

1. Click **"Create New Credential"** → **"Google OAuth2 API"**
2. Follow OAuth flow to authorize
3. Grant access to Google Sheets

---

### Step 2: Verify Environment Variables

The workflow uses these environment variables from `.env`:

```bash
GEMINI_API_KEY          # Required - Google Gemini API
SERPAPI_KEY             # Optional - For recruiter search
GOOGLE_SHEET_ID         # Required - Your tracking sheet ID
JOB_ROLE                # Optional - Defaults to "Software Development Engineer"
JOB_EXPERIENCE          # Optional - Defaults to "1.5"
JOB_SALARY_MIN          # Optional - Defaults to "12"
JOB_SALARY_MAX          # Optional - Defaults to "15"
JOB_LOCATION            # Optional - Defaults to "India"
JOB_KEYWORDS            # Optional - Defaults to "Software Engineer,Full Stack,React,Node.js"
```

**To verify:**
1. Click on **"Initialize Variables"** node
2. Check if values are loading from `$env.VARIABLE_NAME`
3. If not working, restart n8n:
   ```bash
   docker-compose restart
   ```

---

### Step 3: Test Individual Nodes

Before running the full workflow, test key components:

**Test 1: LinkedIn RSS Feed**
1. Click on **"LinkedIn Jobs RSS"** node
2. Click **"Execute Node"** (play button)
3. Should show job listings from LinkedIn
4. If error: Check internet connection

**Test 2: Gemini API**
1. Click on **"Gemini: Analyze Job Match"** node
2. Click **"Execute Node"**
3. Should return AI analysis
4. If error: Verify `GEMINI_API_KEY` in `.env`

**Test 3: Google Sheets**
1. Click on **"Log to Google Sheets"** node
2. Click **"Execute Node"**
3. Should write to your sheet
4. If error: Check sheet is shared with service account

---

### Step 4: Test Full Workflow

1. Make sure your resume is at: `resumes/master-resume.pdf`
2. Click **"Execute Workflow"** (top right, play button)
3. Watch the progress through each node
4. Check your Google Sheet for new entries

**Expected Results:**
- ✅ Jobs found: 5-20 jobs
- ✅ Resume analyzed: Each job gets ATS score
- ✅ Recruiters found: For high-match jobs (ATS > 60%)
- ✅ Google Sheet updated: New rows added

**Common Issues:**

| Error | Solution |
|-------|----------|
| "No jobs found" | LinkedIn URL might need adjustment |
| "Gemini API error" | Check API key, verify quota |
| "Permission denied" (Sheets) | Share sheet with service account |
| "Resume not found" | Verify `/resumes/master-resume.pdf` exists |

---

### Step 5: Activate the Schedule

Once everything works:

1. Click the **toggle switch** in top-right corner
2. It should turn **GREEN** ("Active")
3. The workflow will now run automatically at **9 AM IST daily**

---

## 📊 Workflow Features

### Smart Features Built-In:

1. **Rate Limiting:**
   - 1-second wait between Gemini API calls
   - 2-second wait between jobs
   - Prevents hitting API limits

2. **Error Handling:**
   - Retries failed API calls 3 times
   - Fallback data if parsing fails
   - Continues workflow even if one job fails

3. **Conditional Logic:**
   - Only searches for recruiter if ATS score > 60%
   - Saves API quota for high-quality matches

4. **Deduplication:**
   - Removes duplicate job URLs
   - Filters out irrelevant jobs
   - Sorts by posting date

5. **Daily Summary:**
   - Generates statistics after processing
   - Logs total jobs, avg ATS score, recruiters found

---

## 🎨 Customizing the Workflow

### Change Job Search Criteria

**Edit in `.env` file:**
```bash
JOB_ROLE=Backend Developer
JOB_KEYWORDS=Python,Django,FastAPI,PostgreSQL
JOB_LOCATION=Bangalore
```

**Or edit "Initialize Variables" node:**
- Click on the node
- Change default values
- Click "Save"

### Adjust ATS Threshold

**Edit "Check ATS Score" node:**
1. Click on the node
2. Change `60` to your preferred threshold (e.g., `70` for stricter)
3. Click "Save"

### Add Email Notifications

**After "Generate Daily Summary" node:**
1. Add **"Send Email"** node (Gmail/SMTP)
2. Connect from "Generate Daily Summary"
3. Configure:
   - To: your-email@gmail.com
   - Subject: `Daily Job Report - {{ $json.total_jobs_found }} jobs`
   - Body: 
     ```
     Jobs Found: {{ $json.total_jobs_found }}
     Avg ATS Score: {{ $json.avg_ats_score }}%
     High Matches: {{ $json.high_match_jobs }}
     Recruiters: {{ $json.recruiters_found }}
     ```

### Change Schedule Time

**Edit "Schedule: Every Day at 9 AM IST" node:**
1. Click on the node
2. Change cron expression:
   - `0 9 * * *` = 9 AM daily
   - `0 18 * * *` = 6 PM daily
   - `0 9 * * 1-5` = 9 AM weekdays only
3. Click "Save"

---

## 🔍 Monitoring Executions

### View Execution History

1. Click **"Executions"** in left sidebar
2. See list of all workflow runs
3. Click any execution to see:
   - Input/output for each node
   - Errors (if any)
   - Execution time
   - Data flow

### Check Today's Run

1. Go to Executions
2. Look for today's date
3. Verify:
   - Status: Success ✅
   - Jobs processed
   - No errors

---

## 📝 Updating the Workflow

### To modify:
1. Deactivate workflow (toggle to OFF)
2. Make your changes
3. Test with "Execute Workflow"
4. When working, activate again

### To export (for backup):
1. Click **"..."** menu (top right)
2. Click **"Download"**
3. Save JSON file
4. Commit to git for version control

---

## 🆘 Quick Troubleshooting

### Workflow won't execute
- ✅ Check it's activated (green toggle)
- ✅ Verify Docker container is running
- ✅ Check execution history for errors

### No data in Google Sheets
- ✅ Sheet shared with service account?
- ✅ Correct Sheet ID in `.env`?
- ✅ Test the Google Sheets node individually

### Gemini API errors
- ✅ Valid API key in `.env`?
- ✅ Check quota: https://makersuite.google.com
- ✅ Look for rate limit errors in logs

### Resume not found
- ✅ File at `/resumes/master-resume.pdf`?
- ✅ Volume mounted in docker-compose.yml?
- ✅ Check Docker logs: `docker-compose logs n8n`

---

## 🎯 Next Steps

1. **Run a test execution** to verify everything works
2. **Activate the schedule** for daily automation
3. **Check your sheet tomorrow morning** after first run
4. **Customize as needed** (keywords, threshold, notifications)
5. **Monitor quota usage** to stay within free tiers

---

## 📚 Resources

- **n8n Documentation:** https://docs.n8n.io/
- **Workflow Guide:** See `WORKFLOW_GUIDE.md` for detailed node explanations
- **Troubleshooting:** See `TROUBLESHOOTING.md` for common issues
- **API Strategy:** See `FREE_TOOLS_STRATEGY.md` for quota management

---

**You're all set! The workflow is ready to find and track jobs automatically.** 🚀
