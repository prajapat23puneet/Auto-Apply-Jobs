# 🔍 Complete n8n Debugging Guide

## 🎯 The Debugging Process (Step-by-Step)

### Step 1: Identify Where the Problem Occurs

**Execute nodes ONE BY ONE** to find where data stops flowing:

```
1. Click on first node → Execute Node
2. Check output (green checkmark = data exists)
3. Move to next node → Execute Node
4. Repeat until you find the node with 0 output
```

**Visual indicators:**
- ✅ **Green with number** (e.g., "1 item") = Success, has data
- ❌ **Red with X** = Error occurred
- ⚪ **Gray** = Not executed yet
- ⚠️ **Yellow with 0** = Executed but returned no data

---

## 🔧 Debug Your Job Agent Workflow

### Test Each Source Individually

#### **Test 1: Initialize Variables**

**Execute:** Click "Initialize Variables" → Execute Node

**Expected output:**
```json
{
  "jobRole": "Software Development Engineer",
  "experience": "1.5",
  "location": "India",
  "keywords": "Software Engineer,Full Stack,React",
  "geminiApiKey": "AIza...",
  "serpApiKey": "abc123...",
  "googleSheetId": "1ABC..."
}
```

**If empty:**
```bash
# Problem: .env not loaded
# Fix:
docker-compose down
docker-compose up -d

# Check environment variables in container:
docker-compose exec n8n env | grep JOB_ROLE
```

---

#### **Test 2: LinkedIn Jobs**

**Execute:** Click "LinkedIn Jobs (HTTP)" → Execute Node

**Expected output:**
```
✅ 1 item
data: "<html>...</html>" (HTML content)
```

**Debug checklist:**

1. **Check the output data:**
   ```javascript
   // Click on the node, look at "Output" tab
   // Should see HTML text with job listings
   ```

2. **If empty or error:**
   ```javascript
   // Common issues:
   // - LinkedIn URL changed
   // - Rate limiting
   // - Response format not set to "string"
   ```

3. **Test the URL directly:**
   ```bash
   # Copy the URL from the node
   # Open in browser to see if page loads:
   https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=Software+Engineer&location=India&f_E=2&f_TPR=r604800&start=0
   
   # If you see HTML with jobs → n8n config issue
   # If you see "Access Denied" → LinkedIn blocking
   ```

---

#### **Test 3: Extract LinkedIn Job Cards**

**Execute:** Click "Extract LinkedIn Job Cards" → Execute Node

**Expected output:**
```
✅ 1 item (or more)
jobs: ["<li>...</li>", "<li>...</li>", ...]
```

**Debug:**

1. **Click "Output" tab:**
   ```json
   {
     "jobs": [
       "<li class='job-card'>...",
       "<li class='job-card'>..."
     ]
   }
   ```

2. **If jobs array is empty `[]`:**
   ```javascript
   // Problem: CSS selector doesn't match LinkedIn's HTML structure
   
   // Check the HTML from previous node:
   // 1. Go back to "LinkedIn Jobs (HTTP)"
   // 2. Copy the HTML output
   // 3. Search for job listings in the HTML
   // 4. Update CSS selector in "Extract LinkedIn Job Cards"
   
   // LinkedIn uses different selectors:
   // Try: "li" (current)
   // Or: ".job-search-card"
   // Or: ".base-card"
   // Or: "article"
   ```

3. **How to find the right selector:**
   ```bash
   # Method 1: Use browser DevTools
   1. Open LinkedIn jobs page in browser
   2. Right-click on a job card → Inspect
   3. Look at the HTML element
   4. Copy the class name or tag
   5. Update in n8n HTML Extract node
   
   # Method 2: Search in raw HTML
   1. Copy HTML from "LinkedIn Jobs (HTTP)" output
   2. Search for "Software Engineer" or job title
   3. Look at surrounding HTML structure
   4. Find common parent element for all jobs
   ```

---

#### **Test 4: Parse LinkedIn Jobs**

**Execute:** Click "Parse LinkedIn Jobs" → Execute Node

**Expected output:**
```
✅ 5-10 items
[
  {
    "title": "Software Engineer",
    "company": "Google",
    "url": "https://linkedin.com/...",
    "source": "LinkedIn"
  }
]
```

**Debug:**

1. **If no output:**
   ```javascript
   // Problem: Regex patterns don't match HTML structure
   
   // View the Code node:
   console.log('HTML cards found:', jobsHtml.length);
   console.log('First card preview:', jobsHtml[0]?.substring(0, 500));
   
   // Then execute node and check n8n console/logs
   ```

2. **Update regex patterns:**
   ```javascript
   // Example: If title regex doesn't match
   // Current:
   const titleMatch = html.match(/<h3[^>]*>([^<]+)<\/h3>/i);
   
   // If LinkedIn changed to <h2>:
   const titleMatch = html.match(/<h2[^>]*>([^<]+)<\/h2>/i);
   
   // Or use more flexible pattern:
   const titleMatch = html.match(/<h[23][^>]*>([^<]+)<\/h[23]>/i);
   ```

---

#### **Test 5: Google Jobs (SerpAPI)**

**Execute:** Click "Google Jobs (SerpAPI)" → Execute Node

**Expected output:**
```
✅ 1 item
{
  "jobs_results": [
    {
      "title": "...",
      "company_name": "...",
      "location": "..."
    }
  ]
}
```

**Debug:**

1. **If error or empty:**
   ```javascript
   // Check API key is set:
   // Go to "Initialize Variables" output
   // Look for "serpApiKey": "abc123..."
   
   // If empty or missing:
   // - Add to .env: SERPAPI_KEY=your-key-here
   // - Restart: docker-compose restart
   ```

2. **Test API key manually:**
   ```bash
   # Copy your API key from .env
   # Test in browser:
   https://serpapi.com/search?engine=google_jobs&q=Software+Engineer+India&api_key=YOUR_KEY_HERE
   
   # Should see JSON with job results
   # If error: Check API key or quota
   ```

3. **Check SerpAPI quota:**
   ```bash
   # Visit: https://serpapi.com/users/dashboard
   # Check: "Searches this month: X / 100"
   
   # If 100/100: You've hit the free tier limit
   # Solution: Wait for next month or upgrade
   # Or: Skip SerpAPI (LinkedIn is enough)
   ```

---

#### **Test 6: Naukri.com (Optional)**

**Execute:** Click "Naukri.com Scrape" → Execute Node

**Expected output:**
```
✅ 1 item (HTML)
OR
❌ Error (but workflow continues)
```

**Debug:**

1. **If timeout error:**
   ```javascript
   // Expected! Naukri is unreliable
   // Workflow should continue anyway
   // Check "Continue On Fail" is enabled
   ```

2. **To test if it's working:**
   ```bash
   # Open in browser:
   https://www.naukri.com/software-development-engineer-jobs-in-india
   
   # If page loads → Naukri is up
   # If blocked/captcha → Naukri is blocking scraping
   ```

---

### Test the Merge and Filter

#### **Test 7: Merge Job Sources**

**Execute:** Click "Merge Job Sources" → Execute Node

**Expected output:**
```
✅ 15-25 items (combined from all sources)
```

**Debug:**

1. **Count inputs:**
   ```javascript
   // Check previous nodes:
   // - LinkedIn: X jobs
   // - SerpAPI: Y jobs
   // - Naukri: Z jobs
   // Total should be: X + Y + Z
   ```

2. **If merge has fewer items:**
   ```javascript
   // Some sources may have failed
   // That's OK if you have ANY jobs
   // Minimum acceptable: 5+ jobs
   ```

---

#### **Test 8: Filter & Deduplicate**

**Execute:** Click "Filter & Deduplicate Jobs" → Execute Node

**Expected output:**
```
✅ 10-20 items (duplicates removed)
```

**Debug:**

1. **Check console logs:**
   ```javascript
   // The node should log:
   console.log(`Total jobs before dedup: ${allJobs.length}`);
   console.log(`Unique jobs after dedup: ${uniqueJobs.length}`);
   
   // View logs:
   docker-compose logs -f n8n | grep -i "dedup"
   ```

2. **If ALL jobs filtered out (0 items):**
   ```javascript
   // Problem: Deduplication logic too aggressive
   // OR: All jobs have same URL (which would be weird)
   
   // Check the code:
   // Look for: normalizeUrl() function
   // Temporarily disable dedup to test
   ```

---

## 🐛 Common Issues & Solutions

### Issue 1: "No Jobs Found" but nodes show data

**Symptom:** Nodes execute successfully but final count is 0

**Debug:**
```bash
# Execute each node and check item count:
1. Initialize Variables → 1 item ✅
2. LinkedIn HTTP → 1 item ✅
3. Extract LinkedIn → 1 item ✅
4. Parse LinkedIn → 0 items ❌ ← PROBLEM HERE!

# The issue is in "Parse LinkedIn Jobs"
# LinkedIn changed their HTML structure
```

**Fix:**
See "Test 4: Parse LinkedIn Jobs" above to update regex patterns.

---

### Issue 2: API Key Errors

**Symptom:** "Invalid API key" or "Unauthorized"

**Debug:**
```bash
# Check environment variables:
docker-compose exec n8n env | grep -E "(GEMINI|SERP|GOOGLE)"

# Should show:
GEMINI_API_KEY=AIza...
SERPAPI_KEY=abc123...
GOOGLE_SHEET_ID=1ABC...

# If empty:
# 1. Check .env file exists
cat .env | grep GEMINI_API_KEY

# 2. Restart container
docker-compose restart

# 3. Test Initialize Variables node
# Should show apiKey values
```

---

### Issue 3: Google Sheets Not Updating

**Symptom:** Workflow succeeds but sheet is empty

**Debug:**
```bash
# Test 1: Check Sheet ID
# Execute "Initialize Variables"
# Look for: googleSheetId: "1ABC..."
# Copy this ID and verify it matches your sheet URL

# Test 2: Check credentials
# In n8n: Settings → Credentials → Google Sheets
# Make sure credential is configured

# Test 3: Check sharing
# Open your Google Sheet
# Click Share
# Verify service account email has Editor access

# Test 4: Execute just the Sheets node
# Click "Log to Google Sheets"
# Execute Node
# Check for errors
```

---

### Issue 4: Gemini API Errors

**Symptom:** "API key not valid" or timeout

**Debug:**
```bash
# Test 1: Check API key
# Visit: https://makersuite.google.com/app/apikey
# Verify key is active
# Copy and paste into .env

# Test 2: Check quota
# Visit: https://aistudio.google.com/app/apikey
# Check usage: "X / 1,500 requests today"

# Test 3: Test manually
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=YOUR_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'

# Should return JSON response
```

---

## 📊 Systematic Debugging Checklist

When debugging ANY n8n workflow:

### 1. Start with the basics
```
□ Is n8n running? (docker-compose ps)
□ Are environment variables loaded? (docker-compose exec n8n env)
□ Are credentials configured? (n8n → Settings → Credentials)
□ Is the workflow active? (Toggle switch in workflow)
```

### 2. Execute node by node
```
□ Execute first node → Check output
□ Execute second node → Check output
□ Continue until you find the failing node
□ Focus debugging on that specific node
```

### 3. Check the data flow
```
□ Does the node receive input? (Input tab)
□ Does the node produce output? (Output tab)
□ Is the data format correct? (JSON structure)
□ Are there any error messages? (Error tab)
```

### 4. Read the logs
```bash
# View all logs:
docker-compose logs -f n8n

# Filter by workflow:
docker-compose logs -f n8n | grep -i "workflow"

# Filter by error:
docker-compose logs -f n8n | grep -i "error"

# View specific node:
# (Add console.log in Code nodes)
docker-compose logs -f n8n | grep -i "linkedin"
```

### 5. Test external services
```
□ Test URLs in browser (LinkedIn, Naukri)
□ Test API keys manually (curl commands)
□ Check service status (Is LinkedIn down?)
□ Verify rate limits (API quotas)
```

---

## 🎓 Advanced Debugging Techniques

### Technique 1: Add Debug Nodes

Insert "Set" nodes between workflow steps to inspect data:

```
LinkedIn Parse
  ↓
Set (Debug: Log Job Count)  ← Add this
  ↓
Merge Job Sources
```

In the Set node:
```javascript
{
  "debug_jobs_count": "={{ $json.length }}",
  "debug_first_job": "={{ $json[0] }}",
  "debug_timestamp": "={{ new Date().toISOString() }}"
}
```

---

### Technique 2: Console Logging

Add console.log statements in Code nodes:

```javascript
// At the start:
console.log('=== Parse LinkedIn Jobs START ===');
console.log('Input items:', $input.all().length);

// In the loop:
jobs.forEach((job, index) => {
  console.log(`Job ${index}:`, job.title, job.company);
});

// At the end:
console.log('Output jobs:', jobs.length);
console.log('=== Parse LinkedIn Jobs END ===');

return jobs.map(job => ({ json: job }));
```

View logs:
```bash
docker-compose logs -f n8n | grep "Parse LinkedIn"
```

---

### Technique 3: Execution Data Inspection

n8n stores execution data for debugging:

```
1. Go to workflow
2. Click "Executions" tab (top right)
3. Click on a past execution
4. See the exact data at each node
5. Click on any node to see its input/output
```

**This is GOLD for debugging!**

---

### Technique 4: Manual Test Execution

Test workflow with sample data:

```javascript
// Create a "Manual Trigger" node
// Add sample data:
{
  "test_mode": true,
  "sample_jobs": [
    {
      "title": "Test Job 1",
      "company": "Test Company",
      "url": "https://example.com"
    }
  ]
}

// Then trace through workflow with this data
```

---

### Technique 5: Breakpoint Debugging

Use "Stop and Error" nodes strategically:

```
LinkedIn Parse
  ↓
IF (job count < 5)  ← Add condition
  ↓
Stop and Error: "Too few jobs found, check LinkedIn parsing"
```

---

## 🔍 Specific Debugging Scenarios

### Scenario 1: "LinkedIn returns HTML but parser finds 0 jobs"

**Root cause:** LinkedIn changed their HTML structure

**Debug steps:**
```bash
1. Execute "LinkedIn Jobs (HTTP)"
2. Copy the HTML output
3. Save to file: nano linkedin.html
4. Search for a job title you know exists
5. Look at the HTML around it
6. Identify the correct CSS selector
7. Update "Extract LinkedIn Job Cards" CSS selector
8. Update "Parse LinkedIn Jobs" regex patterns
```

**Example:**
```html
<!-- If you find jobs like this: -->
<div class="job-card-container">
  <h2 class="job-title">Software Engineer</h2>
  <span class="company-name">Google</span>
</div>

<!-- Update selectors to: -->
CSS Selector: ".job-card-container"
Title regex: /<h2[^>]*class="job-title"[^>]*>([^<]+)<\/h2>/i
Company regex: /<span[^>]*class="company-name"[^>]*>([^<]+)<\/span>/i
```

---

### Scenario 2: "Gemini API returns but ATS score is 0"

**Root cause:** Gemini response format changed or parsing failed

**Debug steps:**
```javascript
// In "Gemini: Analyze Job Match" node, add logging:

console.log('Gemini raw response:', response);
console.log('Response text:', response.candidates[0]?.content?.parts[0]?.text);

// Check the logs:
docker-compose logs -f n8n | grep "Gemini"

// Common issues:
// 1. Response has markdown code blocks (```json)
// 2. Response is not valid JSON
// 3. Field names changed (ats_score vs atsScore)
```

---

### Scenario 3: "Workflow runs but Google Sheet stays empty"

**Debug steps:**
```bash
# 1. Check if data reaches the Sheets node
# Execute "Log to Google Sheets"
# Look at Input tab - should see job data

# 2. Check credentials
n8n → Settings → Credentials → Google Sheets OAuth2 API
# Test connection

# 3. Check Sheet ID
# Compare:
# - .env: GOOGLE_SHEET_ID=1ABC...
# - Sheet URL: .../spreadsheets/d/1ABC.../
# Must match!

# 4. Check sheet name
# Default is "Sheet1" (case-sensitive)
# If your sheet is named "Jobs", update node

# 5. Check service account sharing
# Sheet → Share → your-service-account@....iam.gserviceaccount.com
# Must have "Editor" role
```

---

## 📚 Debug Resources

### n8n Documentation
- Expressions: https://docs.n8n.io/code/expressions/
- Error handling: https://docs.n8n.io/workflows/error-handling/
- Logging: https://docs.n8n.io/hosting/logging-monitoring/

### Docker Commands
```bash
# View logs:
docker-compose logs -f n8n

# Access container shell:
docker-compose exec n8n /bin/bash

# Check environment:
docker-compose exec n8n env

# Restart container:
docker-compose restart n8n

# View resource usage:
docker stats job-agent-n8n
```

### Useful grep patterns
```bash
# Find errors:
docker-compose logs n8n | grep -i error

# Find specific workflow:
docker-compose logs n8n | grep -i "daily-job-agent"

# Find API calls:
docker-compose logs n8n | grep -i "http request"

# Find Gemini calls:
docker-compose logs n8n | grep -i "gemini"

# Find job counts:
docker-compose logs n8n | grep -i "found.*jobs"
```

---

## 🎯 Quick Debug Commands

Save these as aliases for quick debugging:

```bash
# Add to ~/.bashrc or ~/.zshrc:

alias n8n-logs='docker-compose logs -f n8n'
alias n8n-errors='docker-compose logs n8n | grep -i error'
alias n8n-restart='docker-compose restart n8n'
alias n8n-env='docker-compose exec n8n env | grep -E "(JOB|GEMINI|SERP|GOOGLE)"'
alias n8n-shell='docker-compose exec n8n /bin/bash'
```

Usage:
```bash
n8n-logs          # View live logs
n8n-errors        # Show all errors
n8n-restart       # Restart n8n
n8n-env           # Check environment variables
n8n-shell         # Access container
```

---

## 🎓 Summary: The Debug Workflow

```
1. Identify the symptom
   ↓
2. Execute nodes one by one
   ↓
3. Find the failing node
   ↓
4. Check input data (Input tab)
   ↓
5. Check output data (Output tab)
   ↓
6. Read error messages (Error tab)
   ↓
7. Check logs (docker-compose logs)
   ↓
8. Add console.log for details
   ↓
9. Test external services (APIs, URLs)
   ↓
10. Fix the issue
   ↓
11. Test the fix
   ↓
12. Execute full workflow
```

---

## 🚀 Your Next Steps

1. **Execute each node individually** in your workflow
2. **Find where data stops flowing** (0 items output)
3. **Focus on that specific node** using the techniques above
4. **Share the specific error** with the debug info and I can help further!

---

**Pro tip:** Always start with the simplest explanation (API key wrong, .env not loaded, wrong URL) before diving into complex debugging!

Good luck debugging! 🔍✨