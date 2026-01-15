# 🚀 Quick Start Guide - 15 Minutes to Job Automation

Get your Daily Job Agent running in 15 minutes or less.

## ⏱️ Time Breakdown
- 5 min: API setup
- 5 min: Docker configuration  
- 5 min: n8n workflow import & test

---

## Step 1: Clone & Setup (2 minutes)

```bash
# If you're starting fresh
git clone <your-repo-url>
cd job-agent-setup

# Run setup script
chmod +x setup.sh
./setup.sh

# This creates:
# - .env file
# - Required directories
# - Generates encryption key
```

---

## Step 2: Get API Keys (5 minutes)

### A. Google Gemini API (REQUIRED - 2 min)
1. Go to: https://makersuite.google.com/app/apikey
2. Click "Create API Key in new project"
3. Copy the key
4. Open `.env` and add: `GEMINI_API_KEY=your-key-here`

✅ **Done!** Free tier: 1,500 requests/day

### B. Google Sheets API (REQUIRED - 3 min)
1. Go to: https://console.cloud.google.com/
2. Create new project: "Job Agent"
3. Enable "Google Sheets API"
4. Create credentials:
   - Type: Service Account
   - Name: "job-agent"
   - Role: Editor
5. Download JSON key
6. Save as `credentials/google-service-account.json`
7. Open the JSON file, copy the email address
8. Add to `.env`: `GOOGLE_SERVICE_ACCOUNT_EMAIL=the-email-from-json`

✅ **Done!** 

### C. SerpAPI (OPTIONAL - 1 min)
1. Go to: https://serpapi.com/users/sign_up
2. Sign up (free tier: 100 searches/month)
3. Get API key from dashboard
4. Add to `.env`: `SERPAPI_KEY=your-key-here`

⚠️ Optional but recommended for better job data

---

## Step 3: Create Google Sheet (2 minutes)

1. Go to: https://sheets.google.com
2. Create new spreadsheet: "Job Applications 2026"
3. Rename "Sheet1" (keep this name!)
4. Add these column headers in Row 1:

```
Date | Company | Role | Salary | Location | JD Link | Recruiter Name | Recruiter Email | Status | ATS Score | Matched Skills | Notes
```

5. Get the Sheet ID from URL:
   ```
   https://docs.google.com/spreadsheets/d/COPY_THIS_PART/edit
   ```

6. Add to `.env`: `GOOGLE_SHEET_ID=the-id-you-copied`

7. Share the sheet:
   - Click "Share" button
   - Add the service account email from credentials JSON
   - Give "Editor" access
   - Click "Send"

✅ **Done!** Your tracking sheet is ready

---

## Step 4: Add Your Resume (1 minute)

```bash
# Copy your resume to the project
cp ~/Documents/my-resume.pdf resumes/master-resume.pdf

# Verify it's there
ls -la resumes/
```

⚠️ Must be named exactly `master-resume.pdf`

---

## Step 5: Start n8n (2 minutes)

```bash
# Start Docker container
docker-compose up -d

# Check if running
docker-compose ps

# Should show:
# NAME                COMMAND             STATUS
# job-agent-n8n       "tini -- /docker-…" Up 30 seconds

# View logs (optional)
docker-compose logs -f n8n
```

✅ **Done!** n8n is running

---

## Step 6: Access n8n Interface (1 minute)

1. Open browser: http://localhost:5678
2. Login with credentials from `.env`:
   - Username: `admin` (or your custom value)
   - Password: `changeme` (or your custom value)

✅ **Done!** You're in!

---

## Step 7: Import Workflow (2 minutes)

### Method 1: Import JSON (Easiest)

1. In n8n, click "Workflows" (top left)
2. Click "Import from File"
3. Select: `workflows/daily-job-agent.json`
4. Click "Import"

### Method 2: Build from Guide

If you want to understand each step:
1. Follow: `workflows/WORKFLOW_GUIDE.md`
2. Build node by node

✅ **Workflow imported!**

---

## Step 8: Configure Workflow (2 minutes)

1. Open the imported workflow
2. Click "Google Sheets" node at the end
3. Click "Select Credential" dropdown
4. Click "Create New Credential"
5. Select "Google Service Account"
6. Upload your `credentials/google-service-account.json` file
7. Click "Save"

✅ **Google Sheets connected!**

---

## Step 9: Test Run (2 minutes)

### Test Individual Nodes

1. Click on "LinkedIn Jobs RSS" node
2. Click "Execute Node" button
3. Should show job listings

If it works:
- ✅ LinkedIn RSS is working

If it fails:
- Check internet connection
- Verify URL encoding

### Test Full Workflow

1. Click "Execute Workflow" (top right)
2. Watch the progress
3. Check for errors in any node

**Expected result:**
- Jobs found: ~10-30
- Resume analyzed: ✅
- Recruiter searched: ✅
- Google Sheet updated: ✅

---

## Step 10: Activate Schedule (1 minute)

1. Make sure the workflow executed successfully
2. Click the toggle switch (top right) to "Active"
3. It should turn GREEN

✅ **Automation activated!** Runs daily at 9 AM IST

---

## 🎉 You're Done!

Your Daily Job Agent will now:
- ✅ Search for jobs every morning at 9 AM
- ✅ Analyze each job with AI
- ✅ Find recruiter contacts
- ✅ Log everything to Google Sheets
- ✅ All completely FREE

---

## 🔍 Quick Verification Checklist

Run through this checklist to make sure everything works:

```
[ ] Docker is running
[ ] n8n container is up (docker-compose ps)
[ ] Can access http://localhost:5678
[ ] Workflow imported successfully
[ ] LinkedIn RSS returns jobs
[ ] Gemini API responds (test with single job)
[ ] Google Sheets updates (check your sheet)
[ ] Workflow is ACTIVE (green toggle)
[ ] Master resume exists at resumes/master-resume.pdf
```

---

## 📊 Monitor Your First Run

### Tomorrow Morning (After 9 AM):

1. Check your Google Sheet for new entries
2. Review the jobs found
3. Check ATS scores
4. Look for recruiter contacts

### View Execution History:

1. In n8n: Click "Executions" (left sidebar)
2. See list of all runs
3. Click any execution to see details
4. Debug any errors

---

## 🐛 Quick Troubleshooting

### "No jobs found"
→ Check `FREE_TOOLS_STRATEGY.md` for LinkedIn URL format

### "Gemini API error"
→ Verify API key in `.env`, check quota at https://makersuite.google.com

### "Google Sheets permission denied"
→ Make sure sheet is shared with service account email

### "Resume not found"
→ Check file is at `resumes/master-resume.pdf`

**For detailed troubleshooting:** See `TROUBLESHOOTING.md`

---

## 🎯 Next Steps

Now that it's working:

1. **Customize search:**
   - Edit `.env` to change job keywords
   - Modify experience level in workflow

2. **Add more job boards:**
   - See `FREE_TOOLS_STRATEGY.md` for options
   - Add new HTTP Request nodes

3. **Optimize:**
   - Reduce API calls if hitting limits
   - Adjust ATS score threshold
   - Add email notifications

4. **Scale up:**
   - Clone for different job types
   - Run multiple instances
   - Add Telegram/Discord alerts

---

## 📚 Resources

- **Full Setup:** `README.md`
- **Workflow Details:** `workflows/WORKFLOW_GUIDE.md`
- **Free Tools:** `FREE_TOOLS_STRATEGY.md`
- **Troubleshooting:** `TROUBLESHOOTING.md`
- **n8n Docs:** https://docs.n8n.io/

---

## 💬 Get Help

If stuck:
1. Check error messages in n8n
2. Review `TROUBLESHOOTING.md`
3. Search n8n community forums
4. Review workflow execution logs

---

## 🎊 Success Metrics

After 1 week, you should see:

- **Jobs tracked:** 50-150
- **Resumes tailored:** 50-150
- **Recruiters found:** 20-50
- **API costs:** $0.00

**Happy job hunting! 🚀**
