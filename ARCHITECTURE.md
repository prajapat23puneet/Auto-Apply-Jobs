# System Architecture

This document explains how all components work together.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Daily Job Agent System                    │
│                  (100% Free, Local Automation)               │
└─────────────────────────────────────────────────────────────┘
                             │
                             ├──────────────────┐
                             │                  │
                    ┌────────▼────────┐  ┌──────▼──────┐
                    │  Docker Engine  │  │  Your Data  │
                    │   (Container)   │  │  (Volumes)  │
                    └────────┬────────┘  └──────┬──────┘
                             │                  │
                    ┌────────▼──────────────────▼──────┐
                    │          n8n Workflow           │
                    │      (Automation Engine)        │
                    └────────┬────────────────────────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
        ┌───────▼───┐  ┌─────▼─────┐  ┌──▼──────┐
        │ Job Search│  │  AI Brain │  │ Storage │
        │  Module   │  │  (Gemini) │  │ (Sheets)│
        └───────────┘  └───────────┘  └─────────┘
```

---

## 📦 Component Breakdown

### 1. Docker Infrastructure

**Purpose:** Runs n8n in isolated environment

**Components:**
- **Docker Engine:** Container runtime
- **Docker Compose:** Orchestration config
- **n8n Container:** Main application

**Files:**
- `docker-compose.yml` - Container configuration
- `n8n_data/` - Persistent storage

**Why Docker?**
- ✅ Consistent environment
- ✅ Easy setup/teardown
- ✅ Isolated from system
- ✅ Version control

---

### 2. n8n Workflow Engine

**Purpose:** Automation orchestration

**Key Features:**
- Visual workflow builder
- Scheduled execution
- Error handling & retry
- Environment variable support

**Access:**
- URL: http://localhost:5678
- Auth: Basic (username/password)

**Data Flow:**
```
Trigger → Process → Action → Log → Repeat
```

---

### 3. Job Search Module

**Purpose:** Find relevant SDE jobs

**Architecture:**
```
┌─────────────────────────────────────┐
│        Job Search Module            │
├─────────────────────────────────────┤
│                                     │
│  Branch 1: LinkedIn RSS (Primary)   │
│  ├─ Free, unlimited                 │
│  ├─ 1-2 year experience filter      │
│  └─ Last 7 days filter              │
│                                     │
│  Branch 2: SerpAPI (Secondary)      │
│  ├─ 100 searches/month free         │
│  ├─ Salary info included            │
│  └─ Fallback if LinkedIn < 10 jobs  │
│                                     │
│  Branch 3: Naukri.com (Backup)      │
│  ├─ Direct HTML scraping            │
│  ├─ India-focused                   │
│  └─ Unlimited & free                │
│                                     │
└─────────────┬───────────────────────┘
              │
              ▼
      ┌───────────────┐
      │ Merge & Filter│
      └───────┬───────┘
              │
              ▼
        [20 Best Jobs]
```

**Data Structure:**
```json
{
  "title": "Software Development Engineer",
  "company": "Example Corp",
  "location": "Bangalore, India",
  "salary": "12-15 LPA",
  "url": "https://...",
  "description": "Full job description...",
  "source": "LinkedIn",
  "posted_date": "2026-01-15"
}
```

---

### 4. AI Brain (Gemini Integration)

**Purpose:** Intelligent resume tailoring

**Process Flow:**
```
┌──────────────┐
│  Job + Resume│
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  Gemini API Request  │
│  (gemini-2.0-flash)  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  AI Analysis         │
│  - Extract keywords  │
│  - Match skills      │
│  - Calculate ATS     │
│  - Tailor summary    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  JSON Response       │
│  {                   │
│    ats_score: 85,    │
│    matched: [...],   │
│    missing: [...],   │
│    summary: "..."    │
│  }                   │
└──────────────────────┘
```

**API Usage:**
- **Endpoint:** `generativelanguage.googleapis.com`
- **Model:** `gemini-2.0-flash-exp`
- **Rate Limit:** 60/min, 1500/day
- **Cost:** FREE

**Prompt Engineering:**
```
Input:
- Master resume text
- Job description
- Requirements

Output:
- ATS match score
- Matched skills
- Missing skills
- Tailored summary
- Key achievements
```

---

### 5. Recruiter Intelligence Module

**Purpose:** Find hiring manager contacts

**Two-Phase Approach:**

**Phase 1: Search**
```
Company Name + "recruiter" + "software engineer" + "site:linkedin.com"
    ↓
[SerpAPI Google Search]
    ↓
[Top 5 LinkedIn Profiles]
```

**Phase 2: Extraction**
```
LinkedIn Search Results
    ↓
[Gemini AI Extraction]
    ↓
{
  recruiter_name: "John Doe",
  recruiter_title: "Technical Recruiter",
  recruiter_email: "john.doe@company.com",
  linkedin_url: "linkedin.com/in/johndoe",
  confidence: "high"
}
```

**Email Pattern Generation:**
Common patterns:
- `firstname.lastname@company.com`
- `firstname@company.com`
- `f.lastname@company.com`

**Optimization:**
- Cache per company (don't search twice)
- Skip for known companies
- Use confidence scoring

---

### 6. Storage & Tracking

**Google Sheets Architecture:**

```
┌─────────────────────────────────────────┐
│         Job Applications Sheet          │
├─────────────────────────────────────────┤
│ Date | Company | Role | Salary | ...    │
├─────────────────────────────────────────┤
│ 2026-01-15 | Google | SDE | 15L | ...   │
│ 2026-01-15 | Amazon | SDE | 14L | ...   │
│ ...                                     │
└─────────────────────────────────────────┘
         │
         ├─ Service Account Access
         ├─ Real-time updates
         └─ No quota limits
```

**Columns:**
1. Date - Application date
2. Company - Company name
3. Role - Job title
4. Salary - Salary range
5. Location - Job location
6. JD Link - Job description URL
7. Recruiter Name - Found via AI
8. Recruiter Email - Generated/found
9. Status - "To Apply", "Applied", "Interview", etc.
10. ATS Score - Match percentage
11. Matched Skills - Comma-separated
12. Notes - Additional info

---

## 🔄 Complete Data Flow

### Morning Execution (9 AM Daily)

```
09:00:00 - Schedule Trigger Fires
    ↓
09:00:01 - Initialize Variables from .env
    ↓
09:00:02 - Parallel Job Search (3 sources)
    ├─ LinkedIn RSS (300ms)
    ├─ SerpAPI (2s)
    └─ Naukri Scrape (1s)
    ↓
09:00:05 - Merge & Deduplicate
    ↓ (20 unique jobs)
    ↓
09:00:06 - Start Processing Loop
    ↓
    ├─ Job 1:
    │   ├─ Read resume (100ms)
    │   ├─ Extract text (500ms)
    │   ├─ Gemini analysis (3s)
    │   ├─ Parse response (100ms)
    │   ├─ Search recruiter (2s)
    │   ├─ Extract with Gemini (3s)
    │   ├─ Log to Sheets (500ms)
    │   └─ Total: ~9s
    ↓
    ├─ Job 2: (~9s)
    ├─ Job 3: (~9s)
    └─ ... (Job 20)
    ↓
09:03:06 - All Jobs Processed (20 × 9s = 3 min)
    ↓
09:03:07 - Workflow Complete
```

**Total Time:** ~3-5 minutes for 20 jobs

---

## 🔐 Security Architecture

### Credentials Storage

```
┌─────────────────────────────────────┐
│      Credential Hierarchy           │
├─────────────────────────────────────┤
│                                     │
│  1. Environment Variables (.env)    │
│     ├─ API Keys                     │
│     ├─ n8n Auth                     │
│     └─ Job Parameters               │
│                                     │
│  2. Docker Environment              │
│     └─ Passes .env to container     │
│                                     │
│  3. n8n Credential Store            │
│     ├─ Encrypted with N8N_ENCRYPTION_KEY
│     └─ Google Service Account JSON  │
│                                     │
│  4. Git Ignored                     │
│     ├─ .env (never committed)       │
│     └─ credentials/ (never committed)│
│                                     │
└─────────────────────────────────────┘
```

**Security Layers:**
1. **Git Ignore:** Credentials never in repo
2. **Encryption:** n8n encrypts stored credentials
3. **Container Isolation:** Credentials only in container
4. **Service Account:** Google APIs use service account (not user OAuth)

---

## 💾 File System Layout

```
job-agent-setup/
│
├── .env                    # Secrets (NEVER commit)
├── .env.example           # Template
├── .gitignore            # Git ignore rules
│
├── docker-compose.yml    # Container config
├── setup.sh             # Setup script
│
├── README.md            # Main documentation
├── QUICKSTART.md       # Fast setup guide
├── FREE_TOOLS_STRATEGY.md  # API details
├── TROUBLESHOOTING.md  # Debug guide
│
├── credentials/         # API credentials
│   └── google-service-account.json
│
├── resumes/            # Your resumes
│   └── master-resume.pdf
│
├── workflows/          # n8n workflows
│   ├── WORKFLOW_GUIDE.md
│   └── daily-job-agent.json
│
└── n8n_data/          # n8n storage (auto-created)
    ├── database.sqlite
    └── ...
```

---

## 🌐 Network Architecture

```
┌─────────────────────────────────────┐
│         Your Computer               │
│                                     │
│  ┌───────────────────────────────┐ │
│  │  Docker Container (n8n)       │ │
│  │  Port: 5678                   │ │
│  │                               │ │
│  │  ┌─────────────────────────┐ │ │
│  │  │  Workflow Engine        │ │ │
│  │  └──────────┬──────────────┘ │ │
│  └─────────────┼────────────────┘ │
└────────────────┼──────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼────┐  ┌───▼────┐  ┌───▼────┐
│LinkedIn│  │ Gemini │  │ Google │
│  (RSS) │  │  API   │  │ Sheets │
└────────┘  └────────┘  └────────┘
  FREE        FREE         FREE
```

**Port Mapping:**
- Host: 5678 → Container: 5678
- Access: http://localhost:5678

**Outbound Connections:**
- LinkedIn: HTTPS (443)
- Gemini API: HTTPS (443)
- SerpAPI: HTTPS (443)
- Google Sheets: HTTPS (443)

**No Inbound:** System doesn't accept external connections

---

## ⚡ Performance Characteristics

### Resource Usage

**Docker Container:**
- Memory: ~200-400 MB
- CPU: <5% (idle), ~20% (running)
- Disk: ~500 MB (n8n + data)

**Execution:**
- Startup: ~30 seconds
- Job processing: ~9 seconds/job
- Total runtime: 3-5 minutes for 20 jobs

### API Quotas

**Daily Limits:**
```
Gemini API:     1,500 requests
  Usage:        ~120 requests (20 jobs × 6 calls)
  Buffer:       92% remaining

SerpAPI:        3 requests/day (100/month)
  Usage:        ~3 requests
  Buffer:       Minimal

LinkedIn RSS:   Unlimited
  Usage:        1 request/day
  Buffer:       ∞

Google Sheets:  Unlimited
  Usage:        ~20 writes/day
  Buffer:       ∞
```

### Scalability

**Current Capacity:**
- Jobs/day: 20
- API budget: 92% free
- Can scale to 200+ jobs/day

**Bottleneck:** Time, not API quota
- 200 jobs × 9s = 30 minutes runtime

---

## 🔄 Workflow State Machine

```
[IDLE] ──schedule──▶ [TRIGGERED]
                          │
                          ▼
                    [SEARCHING]
                          │
                          ▼
                    [PROCESSING]
                     ╱    │    ╲
                    ▼     ▼     ▼
              [Resume][Recruiter][Log]
                     ╲    │    ╱
                          ▼
                    [COMPLETE]
                          │
                          ▼
                      [IDLE]
```

**States:**
- **IDLE:** Waiting for schedule
- **TRIGGERED:** Schedule fired, starting
- **SEARCHING:** Fetching jobs from sources
- **PROCESSING:** Analyzing jobs one by one
- **COMPLETE:** All jobs processed
- **ERROR:** Retry or skip to next job

---

## 🎯 Extension Points

Want to add features? Here are the extension points:

### 1. Add Job Board
```javascript
// Add new HTTP Request node
// Connect to Merge node
// Ensure output format matches:
{
  title, company, location, url, description, salary
}
```

### 2. Add Notification
```javascript
// After "Log to Google Sheets"
// Add Telegram/Discord/Email node
// Send daily summary
```

### 3. Auto-Apply Integration
```javascript
// After resume generation
// Add LinkedIn/Naukri API node
// Submit application automatically
```

### 4. Advanced Filtering
```javascript
// In "Filter & Deduplicate"
// Add company blacklist
// Add keyword scoring
// Add location preferences
```

### 5. Multi-Resume Support
```javascript
// Create resume variants:
// - frontend-resume.pdf
// - backend-resume.pdf
// - fullstack-resume.pdf
// Select based on job keywords
```

---

## 🧪 Testing Strategy

### Unit Testing (Individual Nodes)
```
1. Click on node
2. Click "Execute Node"
3. Verify output
```

### Integration Testing (Full Workflow)
```
1. Click "Execute Workflow"
2. Check each node output
3. Verify Google Sheet update
```

### Production Testing (Scheduled)
```
1. Activate workflow
2. Wait for scheduled run
3. Check execution history
4. Verify results
```

---

## 📊 Monitoring & Observability

### Built-in Monitoring

**Execution History:**
- Location: n8n → Executions
- Retention: All executions saved
- Details: Input/output for each node

**Error Tracking:**
- Failed executions highlighted
- Error messages captured
- Stack traces available

### Custom Monitoring

**Add to workflow:**
```javascript
// Log to Google Sheets "Metrics" tab
{
  date: today,
  jobs_found: count,
  gemini_calls: count,
  serpapi_calls: count,
  execution_time: duration,
  errors: error_count
}
```

### Alerts

**Email on Failure:**
```javascript
// Add email node with condition:
if ($execution.status === 'error') {
  sendEmail('Workflow failed!');
}
```

---

This architecture is designed to be:
- ✅ **Free:** No recurring costs
- ✅ **Local:** Runs on your machine
- ✅ **Secure:** Credentials never leave your system
- ✅ **Scalable:** Can handle 200+ jobs/day
- ✅ **Modular:** Easy to extend
- ✅ **Reliable:** Built-in retry & error handling
