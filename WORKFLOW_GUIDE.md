# n8n Workflow Architecture: Daily Job Agent

## Overview
This document describes the complete n8n workflow structure. You'll build this in the n8n visual interface.

## Workflow Structure

```
[Schedule Trigger (Daily 9 AM)]
    ↓
[Initialize Variables]
    ↓
[Job Search Module] ──┐
    ↓                  │
[Filter & Deduplicate] │ (3 parallel branches)
    ↓                  │
[Loop Through Jobs] ───┘
    ↓
┌───[For Each Job]────────────────────────────┐
│   ↓                                          │
│   [Fetch Job Details]                        │
│   ↓                                          │
│   [Read Master Resume]                       │
│   ↓                                          │
│   [Gemini: Analyze & Tailor Resume] ←──┐    │
│   ↓                                     │    │
│   [Generate Tailored Resume PDF]        │    │
│   ↓                                     │    │
│   [Upload to Google Drive (optional)]   │    │
│   ↓                                     │    │
│   [Find Recruiter Info] ────────────────┘    │
│   ↓                                          │
│   [Log to Google Sheets]                     │
│   ↓                                          │
└──[Continue to Next Job]────────────────────┘
    ↓
[Generate Daily Summary]
    ↓
[End]
```

## Node-by-Node Setup

### 1. Schedule Trigger (Cron)
**Node Type:** Schedule Trigger
- **Trigger Times:** 
  - Mode: "Every Day"
  - Hour: 9
  - Minute: 0
  - Timezone: Asia/Kolkata

### 2. Initialize Variables (Set Node)
**Node Type:** Set
**Purpose:** Set up workflow variables from environment

```javascript
// Values to set:
{
  "jobRole": "{{$env.JOB_ROLE}}",
  "experience": "{{$env.JOB_EXPERIENCE}}",
  "salaryMin": "{{$env.JOB_SALARY_MIN}}",
  "salaryMax": "{{$env.JOB_SALARY_MAX}}",
  "location": "{{$env.JOB_LOCATION}}",
  "keywords": "{{$env.JOB_KEYWORDS}}",
  "today": "={{new Date().toISOString().split('T')[0]}}",
  "processedJobs": 0,
  "newJobs": 0
}
```

### 3. Job Search Module (Merge Node)
**Node Type:** Merge
**Purpose:** Combine results from multiple job sources

Create 3 parallel branches feeding into this merge:

#### Branch 1: LinkedIn Jobs RSS
**Node Type:** RSS Read
- **URL:** `https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords={{$node["Initialize Variables"].json["keywords"]}}&location={{$node["Initialize Variables"].json["location"]}}&f_E=2&f_TPR=r86400`
- **f_E=2** means 1-2 years experience
- **f_TPR=r86400** means posted in last 24 hours

#### Branch 2: Google Jobs via SerpAPI
**Node Type:** HTTP Request

```javascript
// Configuration:
Method: GET
URL: https://serpapi.com/search

// Query Parameters:
{
  "engine": "google_jobs",
  "q": "{{$node["Initialize Variables"].json["jobRole"]}} {{$node["Initialize Variables"].json["location"]}}",
  "hl": "en",
  "api_key": "{{$env.SERPAPI_KEY}}",
  "chips": "date_posted:today"
}

// Headers:
{
  "Accept": "application/json"
}
```

#### Branch 3: Naukri.com Scraper (HTTP Request + HTML Extract)
**Node Type:** HTTP Request

```javascript
// Configuration:
Method: GET
URL: https://www.naukri.com/software-development-engineer-jobs-in-india

// Add HTML Extract node after this to parse job listings
```

### 4. Filter & Deduplicate (Code Node)
**Node Type:** Code (JavaScript)

```javascript
// Combine all job sources and remove duplicates
const allJobs = [];
const seenUrls = new Set();

// Process input items from merge
for (const item of $input.all()) {
  const jobs = item.json.jobs || [item.json];
  
  for (const job of jobs) {
    // Normalize job data
    const normalizedJob = {
      title: job.title || job.job_title || '',
      company: job.company || job.company_name || '',
      location: job.location || '',
      salary: job.salary || job.salary_range || '',
      url: job.url || job.job_url || job.link || '',
      description: job.description || job.snippet || '',
      source: job.source || 'unknown',
      posted_date: job.posted_date || job.date || new Date().toISOString()
    };
    
    // Deduplicate by URL
    if (normalizedJob.url && !seenUrls.has(normalizedJob.url)) {
      seenUrls.add(normalizedJob.url);
      
      // Filter by experience and salary
      const experienceMatch = normalizedJob.description.match(/(\d+)[\s-]+(?:to[\s-]+)?(\d+)?[\s]?(?:years?|yrs?)/i);
      if (experienceMatch) {
        const minExp = parseInt(experienceMatch[1]);
        const maxExp = experienceMatch[2] ? parseInt(experienceMatch[2]) : minExp;
        
        // Check if 1.5 years fits in the range
        if (minExp <= 2 && maxExp >= 1) {
          allJobs.push(normalizedJob);
        }
      } else {
        // If no experience mentioned, include it
        allJobs.push(normalizedJob);
      }
    }
  }
}

// Limit to top 20 jobs per day to stay within API limits
return allJobs.slice(0, 20).map(job => ({ json: job }));
```

### 5. Loop Through Jobs (Split In Batches)
**Node Type:** Split In Batches
- **Batch Size:** 1
- **Options:** Reset after all items processed

### 6. Fetch Job Details (HTTP Request)
**Node Type:** HTTP Request
**Purpose:** Get full job description if not available

```javascript
// Only if job.description is incomplete
Method: GET
URL: {{$json.url}}

// Then use HTML Extract node to get full description
```

### 7. Read Master Resume (Read Binary File)
**Node Type:** Read Binary Files
- **File Path:** `/resumes/master-resume.pdf`
- **Add Binary Property:** `resumeData`

### 8. Convert Resume to Text (Code Node)
**Node Type:** Code (JavaScript)

```javascript
// Extract text from PDF using pdf-parse
// n8n includes this library by default

const pdfParse = require('pdf-parse');

const resumeBinary = $binary.resumeData;
const resumeBuffer = Buffer.from(resumeBinary.data, 'base64');

const pdfData = await pdfParse(resumeBuffer);
const resumeText = pdfData.text;

return {
  json: {
    ...($json),
    resumeText: resumeText
  }
};
```

### 9. Gemini: Analyze & Tailor Resume (HTTP Request)
**Node Type:** HTTP Request
**Purpose:** Use Gemini to create tailored resume content

```javascript
// Configuration:
Method: POST
URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key={{$env.GEMINI_API_KEY}}

// Headers:
{
  "Content-Type": "application/json"
}

// Body (JSON):
{
  "contents": [{
    "parts": [{
      "text": `You are an expert resume optimizer for Software Development Engineer positions in India.

MASTER RESUME:
{{$json.resumeText}}

JOB DESCRIPTION:
Title: {{$json.title}}
Company: {{$json.company}}
Location: {{$json.location}}
Description: {{$json.description}}

TASK:
1. Analyze the job description and identify key skills, technologies, and requirements
2. Create a tailored version of the resume that:
   - Highlights relevant experience and projects
   - Incorporates keywords from the JD naturally
   - Emphasizes matching technical skills (especially React, Next.js, Node.js if mentioned)
   - Maintains truthfulness (never fabricate experience)
   - Optimizes for ATS (Applicant Tracking Systems)

3. Return a JSON response with this structure:
{
  "matched_skills": ["skill1", "skill2"],
  "missing_skills": ["skill3", "skill4"],
  "ats_score": 85,
  "tailored_summary": "A 2-3 sentence professional summary optimized for this role",
  "key_achievements": ["achievement 1", "achievement 2", "achievement 3"],
  "recommended_projects": ["project1", "project2"],
  "resume_sections": {
    "professional_summary": "Tailored summary text",
    "key_skills": ["skill1", "skill2", "skill3"],
    "relevant_experience": "Formatted experience section highlighting matching aspects"
  }
}

Ensure the response is valid JSON only, no markdown formatting.`
    }]
  }],
  "generationConfig": {
    "temperature": 0.4,
    "topK": 32,
    "topP": 1,
    "maxOutputTokens": 2048
  }
}
```

### 10. Parse Gemini Response (Code Node)
**Node Type:** Code (JavaScript)

```javascript
// Extract and parse Gemini's response
const geminiResponse = $json.candidates[0].content.parts[0].text;

// Remove markdown code blocks if present
const cleanJson = geminiResponse.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();

let tailoredContent;
try {
  tailoredContent = JSON.parse(cleanJson);
} catch (e) {
  // Fallback if parsing fails
  tailoredContent = {
    matched_skills: [],
    missing_skills: [],
    ats_score: 0,
    tailored_summary: "Error parsing response",
    key_achievements: [],
    recommended_projects: [],
    resume_sections: {}
  };
}

return {
  json: {
    ...($json),
    tailoredResume: tailoredContent
  }
};
```

### 11. Find Recruiter Info (HTTP Request + Gemini)
**Node Type:** HTTP Request (SerpAPI)

```javascript
// First, search for company recruiters
Method: GET
URL: https://serpapi.com/search

// Query Parameters:
{
  "engine": "google",
  "q": "{{$json.company}} recruiter {{$json.title}} site:linkedin.com",
  "api_key": "{{$env.SERPAPI_KEY}}",
  "num": 5
}
```

**Then:** Code Node to Extract Recruiter Info with Gemini

```javascript
// Use Gemini to extract recruiter details from search results
const searchResults = $json.organic_results || [];

const searchText = searchResults.map(r => 
  `${r.title}\n${r.snippet}\n${r.link}`
).join('\n\n');

// Call Gemini API to extract recruiter info
const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${$env.GEMINI_API_KEY}`;

const response = await $http.post(geminiUrl, {
  contents: [{
    parts: [{
      text: `Extract recruiter information from these search results for ${$json.company}:

${searchText}

Return JSON with:
{
  "recruiter_name": "Full Name or null",
  "recruiter_title": "Job Title or null",
  "recruiter_email": "email@company.com or null (use common patterns like firstname.lastname@company.com)",
  "linkedin_url": "LinkedIn profile URL or null",
  "confidence": "high/medium/low"
}

If you cannot find reliable information, return null values with low confidence.
Return only valid JSON, no markdown.`
    }]
  }],
  generationConfig: {
    temperature: 0.2,
    maxOutputTokens: 512
  }
});

const recruiterJson = response.candidates[0].content.parts[0].text
  .replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();

let recruiterInfo;
try {
  recruiterInfo = JSON.parse(recruiterJson);
} catch {
  recruiterInfo = {
    recruiter_name: null,
    recruiter_email: null,
    linkedin_url: null,
    confidence: "low"
  };
}

return {
  json: {
    ...($json),
    recruiter: recruiterInfo
  }
};
```

### 12. Log to Google Sheets (Google Sheets Node)
**Node Type:** Google Sheets
- **Operation:** Append Row
- **Credential:** Google Service Account (JSON)
- **Sheet ID:** `{{$env.GOOGLE_SHEET_ID}}`
- **Range:** Sheet1!A:L

**Column Mapping:**
```javascript
{
  "Date": "={{$json.today}}",
  "Company": "={{$json.company}}",
  "Role": "={{$json.title}}",
  "Salary": "={{$json.salary}}",
  "Location": "={{$json.location}}",
  "JD Link": "={{$json.url}}",
  "Recruiter Name": "={{$json.recruiter.recruiter_name || 'Not Found'}}",
  "Recruiter Email": "={{$json.recruiter.recruiter_email || 'Not Found'}}",
  "Status": "To Apply",
  "ATS Score": "={{$json.tailoredResume.ats_score}}",
  "Matched Skills": "={{$json.tailoredResume.matched_skills.join(', ')}}",
  "Notes": "Auto-generated on {{$json.today}}"
}
```

### 13. Generate Daily Summary (Code Node)
**Node Type:** Code (Run Once for All Items)

```javascript
// After processing all jobs, create a summary
const allJobs = $input.all();

const summary = {
  date: new Date().toISOString().split('T')[0],
  total_jobs_found: allJobs.length,
  companies: [...new Set(allJobs.map(j => j.json.company))],
  avg_ats_score: allJobs.reduce((sum, j) => sum + (j.json.tailoredResume?.ats_score || 0), 0) / allJobs.length,
  recruiters_found: allJobs.filter(j => j.json.recruiter?.recruiter_email).length
};

return [{ json: summary }];
```

## Rate Limiting & Error Handling

### Add Error Handling to Gemini Nodes
Add a "Continue On Fail" setting and retry logic:

```javascript
// In Gemini HTTP Request nodes, add:
// Settings > Continue On Fail: true
// Settings > Retry On Fail: 3 times, 5 second delay
```

### Rate Limit Management
Add a Wait node between Gemini calls:

**Node Type:** Wait
- **Resume:** After Time Interval
- **Wait Amount:** 1 second (to respect 60 req/min limit)

## Testing the Workflow

1. **Manual Test:** Click "Execute Workflow" button
2. **Test Single Job:** Comment out "Split In Batches" and use a single job
3. **Check Logs:** View execution history for errors
4. **Validate Output:** Check Google Sheet for new entries

## Optimization Tips

1. **Reduce API Calls:** Cache job descriptions if URL seen before
2. **Batch Processing:** Process jobs in smaller batches if hitting rate limits
3. **Conditional Logic:** Skip recruiter search for certain companies
4. **Error Recovery:** Store failed jobs for manual review

## Export Your Workflow

Once built, export via:
- Settings > Export > Download
- Save to `/workflows/daily-job-agent.json`
- Commit to git for version control
