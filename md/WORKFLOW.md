# Workflow Breakdown — 27 Nodes

Complete node-by-node reference for the Daily Job Agent n8n workflow.

---

## Overview

```
[Schedule Trigger]
       ↓
[Initialize Variables]
       ↓
[Read Master Resume] → [Extract Resume Text]
       ↓
[Build Search Query]
       ↓
       ├──────────────────────┐
       ↓                      ↓
[Adzuna Jobs API]    [Google Jobs (SerpAPI)]
[Parse Adzuna JSON]  [Parse SerpAPI JSON]
       └──────────────────────┘
                ↓
        [Merge Job Sources]
                ↓
     [Filter & Deduplicate]
                ↓
          [Jobs Found?]
         YES ↓       NO → end
    [Loop Through Jobs] ←──────────────┐
                ↓                      │
       [Add Resume to Job Data]        │
                ↓                      │
      [Build Gemini Body]              │
                ↓                      │
   [Gemini: Analyze Job Match]         │
                ↓                      │
     [Parse Gemini Response]           │
                ↓                      │
       [Check ATS Score]               │
      ≥60 ↓         <60 ↓             │
[Search for Recruiter] [Skip Recruiter]│
          ↓                ↓          │
[Extract Recruiter w/ AI]  │          │
          ↓                ↓          │
     [Guess Recruiter Info] (fallback) │
               ↓                      │
          [Merge Paths]               │
               ↓                      │
     [Log to Google Sheets]           │
               ↓                      │
       [Wait Between Jobs] ───────────┘
                ↓ (after last job)
     [Generate Daily Summary]
```

---

## Phase 1 — Initialization

### Node 1: Schedule Trigger
- **Type:** Schedule Trigger
- **Runs:** Daily at 9:00 AM IST (`0 9 * * *`)
- **Purpose:** Kicks off the entire workflow automatically

### Node 2: Initialize Variables
- **Type:** Set
- **Reads from:** `.env` file via `$env.*`
- **Outputs these variables for the rest of the workflow:**

| Variable | Env Key | Default |
|---|---|---|
| `jobRole` | `JOB_ROLE` | `Software Development Engineer` |
| `experience` | `JOB_EXPERIENCE` | `1.5` |
| `salaryMin` | `JOB_SALARY_MIN` | `12` |
| `salaryMax` | `JOB_SALARY_MAX` | `15` |
| `location` | `JOB_LOCATION` | `India` |
| `keywords` | `JOB_KEYWORDS` | `Software Engineer,Full Stack,React,Node.js` |
| `geminiApiKey` | `GEMINI_API_KEY` | — |
| `serpApiKey` | `SERPAPI_KEY` | — |
| `googleSheetId` | `GOOGLE_SHEET_ID` | — |
| `adzunaKey` | `ADZUNA_KEY` | — |
| `adzunaId` | `ADZUNA_ID` | — |
| `hunterApiKey` | `HUNTER_API_KEY` | — |
| `scrapeApiKey` | `SCRAPE_API_KEY` | — |
| `today` | — | auto: `YYYY-MM-DD` |
| `timestamp` | — | auto: ISO string |

### Node 3: Read Master Resume (Once)
- **Type:** Read Binary File
- **Path:** `/home/node/.n8n-files/resumes/master-resume.pdf`
- **Why once:** Resume is read here and passed through the loop — avoids redundant file reads for every job

### Node 4: Extract Resume Text
- **Type:** Extract From File
- **Input:** PDF binary from Node 3
- **Output:** Plain text stored as `resumeText` — reused for all 20+ jobs

---

## Phase 2 — Job Search

### Node 5: Build Search Query
- **Type:** Set
- **Purpose:** Constructs `searchQuery` from `jobRole` + carries `resumeText` forward
- **Output:**
  - `searchQuery` = value from Initialize Variables `jobRole`
  - `resumeText` = extracted PDF text

### Node 6: Adzuna Jobs API *(Primary Source)*
- **Type:** HTTP Request
- **Method:** GET
- **URL:** `https://api.adzuna.com/v1/api/jobs/in/search/1`
- **Key Params:**
  - `app_id` = `ADZUNA_ID`
  - `app_key` = `ADZUNA_KEY`
  - `results_per_page` = 50
  - `what` = `searchQuery` (URL encoded)
  - `where` = `location` (URL encoded)
  - `max_days_old` = 7
- **Free tier:** 250 req/day
- **Returns:** JSON with `results[]` array

### Node 7: Parse Adzuna JSON
- **Type:** Code (JavaScript)
- **Input:** Adzuna raw response (string or JSON)
- **Logic:** Handles both string and object response formats, extracts from `results`, `jobs`, or `data.results`
- **Output schema per job:**
```json
{
  "title": "...",
  "company": "...",
  "location": "...",
  "url": "...",
  "description": "...",
  "salary": "...",
  "source": "Adzuna",
  "posted_date": "..."
}
```

### Node 8: Google Jobs via SerpAPI *(Secondary Source)*
- **Type:** HTTP Request
- **URL:** `https://serpapi.com/search`
- **Params:**
  - `engine` = `google_jobs`
  - `q` = `{jobRole} {location}`
  - `gl` = `in` (India)
  - `chips` = `date_posted:week`
  - `api_key` = `SERPAPI_KEY`
- **Free tier:** 100 searches/month (~3/day budget)
- **Returns:** JSON with `jobs_results[]`

### Node 9: Parse SerpAPI JSON
- **Type:** Code (JavaScript)
- **Input:** SerpAPI response
- **Extracts:** `title`, `company_name`, `location`, `share_link`, `description`, `detected_extensions.salary`, `detected_extensions.posted_at`
- **Output:** Same schema as Adzuna with `source: "SerpAPI"`

---

## Phase 3 — Merge & Filter

### Node 10: Merge Job Sources
- **Type:** Merge
- **Mode:** Combine all items from Adzuna + SerpAPI
- **Total before filter:** ~50–65 jobs

### Node 11: Filter & Deduplicate Jobs
- **Type:** Code (JavaScript)
- **Logic:**
  - Normalize URLs (strip UTM params, lowercase, trim slashes)
  - Deduplicate by normalized URL
  - Filter by salary range (if detectable)
  - Filter by experience keywords
- **Output:** ~20 unique, relevant jobs

### Node 12: Jobs Found?
- **Type:** IF
- **Condition:** `items.length > 0`
- **True path:** Continue to loop
- **False path:** Skip to Generate Daily Summary

---

## Phase 4 — AI Analysis Loop

### Node 13: Loop Through Jobs
- **Type:** Split In Batches
- **Batch size:** 1 (processes one job at a time)
- **Purpose:** Prevents Gemini API rate limiting

### Node 14: Add Resume to Job Data
- **Type:** Set
- **Attaches:** `resumeText` from Node 4 to current job item
- **Reference:** `$node['Extract Resume Text'].json`

### Node 15: Build Gemini Body
- **Type:** Code (JavaScript)
- **Purpose:** Constructs the full Gemini API request body JSON
- **Prompt includes:** resume text + job title + company + description
- **Asks Gemini to return:**
```json
{
  "ats_score": 75,
  "matched_skills": ["React", "Node.js"],
  "missing_skills": ["AWS", "Docker"],
  "recommendation": "apply"
}
```

### Node 16: Gemini: Analyze Job Match
- **Type:** HTTP Request
- **URL:** `https://generativelanguage.googleapis.com/...`
- **Model:** `gemini-2.0-flash-exp`
- **Temperature:** 0.1 (deterministic)
- **Max tokens:** 512–1024
- **Free tier:** 1,500 req/day (workflow uses ~40/day)

### Node 17: Parse Gemini Response
- **Type:** Code (JavaScript)
- **Input:** Raw Gemini response
- **Extracts:** `ats_score`, `matched_skills`, `missing_skills`, `recommendation`
- **Handles:** JSON parsing, malformed responses, fallback values

### Node 18: Check ATS Score
- **Type:** IF
- **Condition:** `ats_score >= 60`
- **True (≥60%):** Search for recruiter → worth the API call
- **False (<60%):** Skip recruiter search → save SerpAPI quota

---

## Phase 5 — Recruiter Discovery

### Node 19: Search for Recruiter *(ATS ≥ 60 only)*
- **Type:** HTTP Request (SerpAPI)
- **Query:** `LinkedIn recruiter {company} software engineer`
- **Returns:** Top 5 LinkedIn profile snippets
- **Consumes:** ~1 SerpAPI credit per high-scoring job

### Node 20: Extract Recruiter with AI
- **Type:** Code (JavaScript + Gemini API)
- **Input:** SerpAPI search snippets
- **Gemini prompt:** Extract recruiter name, title, email, LinkedIn URL from results
- **Validation rules:**
  - If confidence = `low` → set email to `null`
  - If no name found → set email to `null`
  - Avoids polluting Sheets with garbage data
- **Output:**
```json
{
  "recruiter_name": "Jane Doe",
  "recruiter_title": "Technical Recruiter",
  "recruiter_email": "jane@company.com",
  "linkedin_url": "https://linkedin.com/in/janedoe",
  "confidence": "high"
}
```

### Node 21: Skip Recruiter Search *(ATS < 60)*
- **Type:** Set
- **Sets:** `recruiter = null` and passes job data through unchanged

### Node 22: Guess Recruiter Info *(Fallback)*
- **Type:** Code (JavaScript)
- **Triggers when:** Recruiter extraction fails or returns low confidence
- **Strategy:**
  1. Derive domain from company name (e.g. `google.com`)
  2. Call **Hunter.io API** (`/v2/domain-search?department=hr&limit=1`)
  3. If Hunter finds someone → use their email + name
  4. If Hunter fails → fallback to `careers@domain.com` + `HR Team`
- **Source tag:** `hunter_io` or `hunter_fallback`
- **Env required:** `HUNTER_API_KEY`

---

## Phase 6 — Logging

### Node 23: Merge Paths
- **Type:** Merge
- **Combines:** Job data + ATS result + recruiter info (from either branch)

### Node 24: Log to Google Sheets
- **Type:** Google Sheets (Append Row)
- **Auth:** Google Service Account (JSON credentials)
- **Sheet:** Configured via `GOOGLE_SHEET_ID`
- **Tab:** `Sheet1`
- **Columns written:**

| Column | Value |
|---|---|
| Date | `today` from Initialize Variables |
| Company | `company` |
| Role | `title` |
| Salary | `salary` |
| Location | `location` |
| JD Link | `url` |
| Recruiter Name | `recruiter.recruiter_name` |
| Recruiter Email | `recruiter.recruiter_email` |
| Confidence | `recruiter.confidence` |
| Status | `To Apply` (hardcoded) |
| ATS Score | `ats_score` |
| Matched Skills | `matched_skills` (comma-separated) |
| Notes | AI-generated notes |

### Node 25: Wait Between Jobs
- **Type:** Wait
- **Delay:** 2 seconds
- **Purpose:** Respect Gemini API rate limits, prevent throttling
- **After wait:** Loop continues to next job

---

## Phase 7 — Summary

### Node 26: Generate Daily Summary *(after loop ends)*
- **Type:** Code (JavaScript)
- **Calculates:**
  - Total jobs found
  - Average ATS score
  - High/medium confidence recruiters found
  - Jobs by source (Adzuna vs SerpAPI)
  - Top matched skills frequency
- **Output format:**
```
Daily Job Agent Summary - 2026-01-16
• Jobs found: 20
• Avg ATS score: 72%
• High confidence recruiters: 5
• Medium confidence: 8
• Sources: Adzuna(35), SerpAPI(15)
• Top skills: React(15), Node.js(12), Python(9)
```

---

## Key Design Decisions

**Why Adzuna over LinkedIn?** LinkedIn blocks scrapers with Cloudflare. Adzuna has a proper free API with 250 req/day, structured JSON, and India-specific data (`/jobs/in/` endpoint).

**Why read resume once?** Reading PDF + text extraction takes ~600ms. With 20 jobs, reading inside the loop wastes 12 seconds and adds complexity. Reading once outside the loop and passing `resumeText` as a variable is faster and simpler.

**Why Hunter.io as fallback?** When Gemini + SerpAPI can't find a real recruiter, `careers@company.com` is useless. Hunter.io domain search finds actual HR team emails from their database, making the fallback genuinely useful.

**Why 2-second wait between jobs?** Gemini Flash free tier allows 60 req/min. Each job uses 2 Gemini calls. 20 jobs × 2 calls = 40 calls/minute without wait — dangerously close to the limit. 2-second wait brings it to ~20 calls/minute.

**Why ATS ≥ 60 threshold for recruiter search?** Recruiter search costs SerpAPI credits (100/month free). Wasting them on 30% ATS jobs is inefficient. Only jobs with a real chance of response are worth the credit.

---

## Environment Variables Reference

```env
# Job Preferences
JOB_ROLE=Software Development Engineer
JOB_EXPERIENCE=1.5
JOB_SALARY_MIN=12
JOB_SALARY_MAX=15
JOB_LOCATION=India
JOB_KEYWORDS=Software Engineer,Full Stack,React,Node.js

# Required APIs
GEMINI_API_KEY=            # Google AI Studio
SERPAPI_KEY=               # serpapi.com
ADZUNA_ID=                 # developer.adzuna.com (App ID)
ADZUNA_KEY=                # developer.adzuna.com (App Key)
GOOGLE_SHEET_ID=           # from Google Sheets URL

# Optional APIs
HUNTER_API_KEY=            # hunter.io (improves recruiter fallback)
SCRAPE_API_KEY=            # reserved for future scraping node

# n8n Config
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=yourpassword
N8N_ENCRYPTION_KEY=        # any random 32-char string
```
