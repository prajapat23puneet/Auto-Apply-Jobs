# Daily Job Agent - Free Local Automation System

A completely free, local job hunting automation system using n8n, Docker, and Google Gemini API.

## 🎯 What This Does

- **Daily Job Search**: Automatically searches for SDE jobs matching your criteria
- **Smart Resume Tailoring**: Uses Google Gemini AI to customize your resume for each job
- **Recruiter Intelligence**: Finds recruiter contact information
- **Application Tracking**: Logs everything to Google Sheets
- **100% Free**: No paid APIs required

## 📋 Prerequisites

1. Docker & Docker Compose installed
2. Google Account (for Sheets API & Gemini API)
3. Basic understanding of n8n workflows

## 🚀 Quick Start

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Fill in your API keys in .env (see setup guide below)

# 3. Start the system
docker-compose up -d

# 4. Access n8n at http://localhost:5678
# Default credentials are in docker-compose.yml
```

## 🔑 API Setup Guide

### 1. Google Gemini API (FREE)
- Go to: https://makersuite.google.com/app/apikey
- Click "Create API Key"
- Copy the key to `.env` as `GEMINI_API_KEY`
- Free tier: 60 requests/minute, 1500 requests/day

### 2. Google Sheets API
- Go to: https://console.cloud.google.com/
- Create a new project (or use existing)
- Enable "Google Sheets API"
- Create credentials (Service Account)
- Download JSON key file
- Save as `credentials/google-service-account.json`
- Share your tracking sheet with the service account email

### 3. SerpAPI (FREE Tier)
- Go to: https://serpapi.com/
- Sign up for free account
- Get API key (100 searches/month free)
- Add to `.env` as `SERPAPI_KEY`

### 4. RapidAPI (for LinkedIn Scraper - FREE)
- Go to: https://rapidapi.com/
- Subscribe to "LinkedIn Data Scraper" (free tier)
- Get API key
- Add to `.env` as `RAPIDAPI_KEY`

## 📁 File Structure

```
job-agent-setup/
├── docker-compose.yml          # Docker orchestration
├── .env.example               # Template for environment variables
├── .env                       # Your actual secrets (git-ignored)
├── .gitignore                # Git ignore rules
├── credentials/              # API credentials
│   └── google-service-account.json
├── n8n_data/                # n8n persistent data (auto-created)
├── resumes/                 # Your master resume storage
│   └── master-resume.pdf
├── workflows/               # n8n workflow exports
│   └── daily-job-agent.json
└── README.md               # This file
```

## 🔧 Configuration

1. **Master Resume**: Place your resume in `resumes/master-resume.pdf`
2. **Google Sheet**: Create a sheet with these columns:
   - Date | Company | Role | Salary | Location | JD Link | Recruiter Name | Recruiter Email | Status | Tweaked Resume Link | Notes

3. **Environment Variables**: See `.env.example` for all required variables

## 📊 Workflow Components

### Module 1: Job Search Engine
- **LinkedIn Jobs RSS**: Free job feeds by keywords
- **Google Custom Search**: Free tier (100 queries/day)
- **SerpAPI**: Google Jobs scraping (100/month free)

### Module 2: Resume Tailoring
- Reads master resume
- Analyzes job description with Gemini
- Generates keyword-optimized resume
- Stores in Google Drive (free 15GB)

### Module 3: Recruiter Intelligence
- Searches company website
- LinkedIn search via SerpAPI
- Email pattern detection
- Gemini-powered extraction

### Module 4: Tracking & Notifications
- Logs to Google Sheets
- Daily summary (optional email)

## 🔒 Security Best Practices

- `.env` is git-ignored by default
- Never commit API keys
- Use service accounts for Google APIs
- Rotate keys periodically

## 🛠️ Customization

Edit these in the n8n workflow:
- Job search keywords
- Experience level filters
- Salary range
- Location preferences
- Schedule timing (default: 9 AM daily)

## 📝 Usage

1. The workflow runs automatically every day at 9 AM
2. Check your Google Sheet for new applications
3. Review and send tailored resumes
4. Update status column as you apply

## 🐛 Troubleshooting

- **n8n won't start**: Check Docker logs with `docker-compose logs -f`
- **API errors**: Verify keys in `.env` and API quotas
- **No jobs found**: Adjust search parameters in workflow
- **Gemini rate limits**: Workflow includes retry logic

## 📈 Extending the System

- Add more job boards (modular design)
- Integrate email automation
- Add application follow-up reminders
- Connect to LinkedIn for auto-apply

## 🤝 Contributing

Feel free to fork and customize for your needs!

## 📄 License

MIT License - Free to use and modify
