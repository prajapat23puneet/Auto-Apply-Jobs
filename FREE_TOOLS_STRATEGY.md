# Free Tools Strategy Guide

This guide explains exactly which free tools to use and how to stay within free tier limits.

## 🎯 Core Philosophy

**100% Free Automation** using:
1. Rate-limited free APIs
2. Smart caching to minimize API calls
3. RSS feeds (unlimited & free)
4. Intelligent fallbacks

---

## 📊 API Usage Budget (Per Day)

| Service | Free Limit | Our Usage | Buffer |
|---------|-----------|-----------|--------|
| Gemini API | 1,500 req/day | ~60 jobs × 2 calls = 120 | ✅ 1,380 remaining |
| SerpAPI | 100 req/month | ~3/day | ✅ 97% buffer |
| Google Sheets | Unlimited (with service account) | ~60 writes/day | ✅ Free |
| RSS Feeds | Unlimited | Unlimited | ✅ Free |

---

## 🔍 Job Search Strategy (FREE Methods)

### Method 1: LinkedIn Jobs RSS (PRIMARY - Unlimited)

**Why:** LinkedIn provides RSS feeds for job searches - completely free, unlimited

**Setup:**
```
Base URL: https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search

Parameters:
- keywords: Software%20Development%20Engineer
- location: India
- f_E: 2 (1-2 years experience)
- f_TPR: r86400 (last 24 hours)
- start: 0 (pagination)

Full URL Example:
https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=Software%20Development%20Engineer&location=India&f_E=2&f_TPR=r86400&start=0
```

**n8n Implementation:**
- Node Type: RSS Read
- Update every 24 hours
- Returns: Job title, company, location, link, description snippet

**Pros:**
- ✅ Unlimited requests
- ✅ No API key needed
- ✅ Fresh jobs (last 24 hours)
- ✅ Experience level filtering

**Cons:**
- ⚠️ Limited description (need to fetch full page)
- ⚠️ No salary info

---

### Method 2: Google Jobs via SerpAPI (SECONDARY - 100/month)

**Why:** High-quality structured data, salary info included

**Free Tier:** 100 searches/month = ~3 per day

**Setup:**
1. Sign up: https://serpapi.com/
2. Get API key (free tier)
3. Use "google_jobs" engine

**API Call:**
```json
GET https://serpapi.com/search
{
  "engine": "google_jobs",
  "q": "Software Development Engineer India",
  "hl": "en",
  "api_key": "YOUR_KEY",
  "chips": "date_posted:today"
}
```

**n8n Implementation:**
- Node Type: HTTP Request
- Use only if LinkedIn RSS finds < 10 jobs
- Cache results for 24 hours

**Pros:**
- ✅ Salary information
- ✅ Company reviews/ratings
- ✅ Structured data
- ✅ Multiple job boards aggregated

**Cons:**
- ⚠️ Limited to 100/month (use sparingly)

---

### Method 3: Naukri.com Web Scraping (UNLIMITED)

**Why:** India's largest job board, no API needed

**Method:** Direct HTML scraping

**n8n Implementation:**
```javascript
// HTTP Request Node
URL: https://www.naukri.com/software-development-engineer-jobs-in-india

// HTML Extract Node (CSS Selectors)
Job Title: .title
Company: .company
Location: .location
Salary: .salary
Link: .title > a [href]
```

**Pros:**
- ✅ Unlimited & free
- ✅ India-focused
- ✅ Salary ranges

**Cons:**
- ⚠️ HTML structure may change
- ⚠️ Need to parse messy HTML
- ⚠️ Rate limit responsibly (add 2-second delay)

---

### Method 4: Indeed RSS (BACKUP - Unlimited)

**Why:** Free RSS feed, no API key

**URL Pattern:**
```
https://www.indeed.co.in/rss?q=Software+Development+Engineer&l=India&fromage=1
```

**n8n Implementation:**
- Node Type: RSS Read
- Fallback if LinkedIn fails
- Indian job market focus

---

## 🤖 Recruiter Finding Strategy (FREE)

### Approach 1: Google Search + Gemini Extraction (PRIMARY)

**Cost:** 1 Gemini API call per job (~60/day total)

**Process:**
1. Use SerpAPI free search (save quota by searching once per company, not per job)
2. Search query: `"[Company Name]" recruiter "software engineer" site:linkedin.com`
3. Parse results with Gemini to extract:
   - Recruiter name
   - Likely email pattern
   - LinkedIn profile

**n8n Implementation:**
```javascript
// SerpAPI Search (1 call per unique company)
GET https://serpapi.com/search
{
  "engine": "google",
  "q": "{company} recruiter software engineer site:linkedin.com",
  "num": 5,
  "api_key": "YOUR_KEY"
}

// Then: Gemini extraction (see WORKFLOW_GUIDE.md)
```

**Email Pattern Generation:**
Common patterns:
- firstname.lastname@company.com
- firstname@company.com
- f.lastname@company.com

**Gemini Prompt:**
```
Given this company: [Company Name]
And these LinkedIn profiles: [Search Results]

Generate likely recruiter email addresses using common patterns.
Rank by confidence (high/medium/low).
```

---

### Approach 2: Hunter.io Free Tier (BACKUP)

**Free Tier:** 25 searches/month

**Setup:**
1. Sign up: https://hunter.io/
2. Get API key
3. Use only for high-priority companies

**API:**
```json
GET https://api.hunter.io/v2/domain-search
{
  "domain": "company.com",
  "api_key": "YOUR_KEY",
  "department": "engineering"
}
```

**Strategy:** Use only when Gemini has low confidence

---

### Approach 3: Company Website Scraping (FREE)

**Method:** Check company careers page for contact info

**n8n Implementation:**
```javascript
// HTTP Request
URL: https://www.google.com/search?q={company}+careers+contact

// HTML Extract
Look for: "careers@", "recruiting@", "talent@"
```

---

## 📝 Resume Generation Strategy

### Gemini API for Resume Tailoring (FREE - 1,500/day)

**Usage:** 2 calls per job
1. Analysis call (extract JD keywords)
2. Tailoring call (generate resume content)

**Daily Capacity:**
- 1,500 requests / 2 per job = 750 jobs/day
- **Our usage:** ~60 jobs/day = 120 requests
- **Buffer:** 92% free capacity remaining

**Optimization:**
- Combine both calls into 1 if possible
- Cache company-specific insights
- Skip re-processing same JD URLs

---

## 💾 Storage Strategy (FREE)

### Google Drive Free Tier (15 GB)

**What to store:**
- Tailored resume PDFs
- Job description archives
- Daily summary reports

**n8n Implementation:**
- Use Google Drive node
- Organize by date: `/Job Applications/2026/01/`
- Share links in Google Sheets

### Alternative: Local File System

**What to store:**
- Raw data backups
- Logs
- Temporary files

**Location:** `/home/claude/job-agent-setup/data/`

---

## 📊 Tracking Strategy (FREE)

### Google Sheets API (Unlimited with Service Account)

**Why:** No quota limits for service accounts

**Sheet Structure:**
```
Columns:
- Date
- Company
- Role
- Salary
- Location
- JD Link
- Recruiter Name
- Recruiter Email
- Status (To Apply, Applied, Interview, Rejected, Offer)
- ATS Score
- Matched Skills
- Notes
```

**Advanced Features:**
- Conditional formatting (highlight high ATS scores)
- Data validation (status dropdown)
- Formulas (count applications per company)
- Charts (applications over time)

---

## 🚀 Optimization Tactics

### 1. Caching Strategy
```javascript
// Cache job URLs for 7 days to avoid reprocessing
const seenJobs = new Set();
// Store in n8n static data or Google Sheets

if (seenJobs.has(job.url)) {
  skip(); // Don't process again
}
```

### 2. Rate Limit Management
```javascript
// Add delays between API calls
Wait Node: 1 second between Gemini calls
Wait Node: 2 seconds between web scrapes
```

### 3. Fallback Chain
```
LinkedIn RSS (primary)
  ↓ (if < 10 jobs)
Google Jobs via SerpAPI (3/day)
  ↓ (if still < 10)
Naukri.com Scraping (unlimited)
  ↓ (if still < 10)
Indeed RSS (unlimited)
```

### 4. Smart Scheduling
- Run at 9 AM (low API traffic time)
- Process jobs sequentially to avoid rate limits
- Skip weekends (fewer new postings)

---

## 📈 Scaling Within Free Tier

### Current Capacity
- **Jobs per day:** 60 (limited by Gemini at 2 calls/job)
- **Recruiter searches:** 30/day (conserve SerpAPI)
- **Resume variants:** 60/day

### If You Need More
1. **Multiple Gemini Accounts:** Create 2-3 Google accounts, rotate keys
2. **Reduce API Calls:** 
   - Cache job descriptions
   - Skip recruiter search for known companies
   - Reuse resume variants for similar roles
3. **Selective Processing:**
   - Filter by company size
   - Prioritize high-match jobs
   - Skip "easy apply" jobs

---

## 🔐 Security Best Practices

### API Key Rotation
```bash
# Rotate keys monthly
cp .env .env.backup.$(date +%Y%m%d)
# Generate new keys
# Update .env
docker-compose restart
```

### Rate Limit Monitoring
```javascript
// Add to workflow: Track API usage
{
  "gemini_calls_today": count,
  "serpapi_calls_today": count,
  "date": today
}
// Store in Google Sheets "API Usage" tab
```

---

## 🎓 Learning Resources

### n8n Tutorials
- Official Docs: https://docs.n8n.io/
- Community: https://community.n8n.io/
- Templates: https://n8n.io/workflows/

### API Documentation
- Gemini: https://ai.google.dev/docs
- SerpAPI: https://serpapi.com/google-jobs-api
- Google Sheets: https://developers.google.com/sheets/api

### Web Scraping
- CSS Selectors: https://www.w3schools.com/cssref/css_selectors.asp
- HTML Extract: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.html/

---

## ✅ Checklist: Setting Up Free Tools

- [ ] Sign up for Google Gemini API (FREE)
- [ ] Sign up for SerpAPI (FREE - 100/month)
- [ ] Create Google Cloud Project for Sheets API (FREE)
- [ ] (Optional) Sign up for RapidAPI (FREE tier)
- [ ] (Optional) Sign up for Hunter.io (FREE - 25/month)
- [ ] Set up Google Sheet for tracking
- [ ] Configure service account and share sheet
- [ ] Test each API individually before integrating

---

## 🐛 Troubleshooting Free Tier Issues

### "API Quota Exceeded"
**Gemini:**
- Check daily limit (1,500/day)
- Add retry with exponential backoff
- Create secondary Google account

**SerpAPI:**
- You've used 100 searches this month
- Wait until next month or upgrade
- Use RSS feeds as fallback

### "Rate Limited"
- Add Wait nodes (1-2 seconds)
- Reduce batch size
- Run workflow at off-peak hours

### "Service Account Permission Denied"
- Verify sheet is shared with service account email
- Check API is enabled in Google Cloud Console
- Regenerate credentials if needed

---

## 💡 Pro Tips

1. **LinkedIn is Your Best Friend:** Their RSS feeds are unlimited and updated hourly
2. **Batch Process Smartly:** Group jobs by company to reuse recruiter searches
3. **Monitor Your Usage:** Create a dashboard in Google Sheets to track API calls
4. **Set Alerts:** Get notified when quota is 80% used
5. **Fallback Always:** Every paid API should have a free alternative

---

**Remember:** This entire system runs on free tiers. The only cost is your time to set it up!
