#!/bin/bash

#==============================================================================
# Daily Job Agent - Interactive Setup Script
# This script automates the setup process from QUICKSTART.md
#==============================================================================

set -e  # Exit on error

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Unicode symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"
STAR="${YELLOW}★${NC}"
ROCKET="${MAGENTA}🚀${NC}"

#==============================================================================
# Helper Functions
#==============================================================================

print_header() {
    echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${BOLD}${MAGENTA}▸${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "  ${CHECK} $1"
}

print_error() {
    echo -e "  ${CROSS} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC}  $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC}  $1"
}

print_action() {
    echo -e "  ${ARROW} $1"
}

ask_question() {
    echo -e "${CYAN}❯${NC} ${BOLD}$1${NC}"
}

wait_for_enter() {
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read -r
}

#==============================================================================
# Main Setup Process
#==============================================================================

clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                   🤖  DAILY JOB AGENT SETUP  🤖                   ║
║                                                                   ║
║              Your Personal AI Recruiter - 100% Free              ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

EOF

echo -e "${BOLD}This script will set up your job automation system in ~15 minutes.${NC}\n"
echo -e "What we'll do:"
echo -e "  ${CHECK} Create directory structure"
echo -e "  ${CHECK} Generate .env configuration file"
echo -e "  ${CHECK} Set up encryption keys"
echo -e "  ${CHECK} Guide you through API key setup"
echo -e "  ${CHECK} Create sample Google Sheet"
echo -e "  ${CHECK} Verify all prerequisites"

wait_for_enter

#==============================================================================
# Step 1: Check Prerequisites
#==============================================================================

print_header "Step 1: Checking Prerequisites"

# Check Docker
print_step "Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    print_success "Docker installed (version $DOCKER_VERSION)"
else
    print_error "Docker is not installed"
    echo -e "\n${YELLOW}Please install Docker first:${NC}"
    echo -e "  ${ARROW} Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
print_step "Checking Docker Compose..."
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f4 | cut -d ',' -f1)
    print_success "Docker Compose installed (version $COMPOSE_VERSION)"
elif docker compose version &> /dev/null 2>&1; then
    print_success "Docker Compose (plugin) installed"
    # Use docker compose instead of docker-compose
    alias docker-compose='docker compose'
else
    print_error "Docker Compose is not installed"
    echo -e "\n${YELLOW}Please install Docker Compose:${NC}"
    echo -e "  ${ARROW} Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    print_error "docker-compose.yml not found in current directory"
    echo -e "\n${YELLOW}Please run this script from the job-agent-setup directory${NC}"
    exit 1
fi

print_success "All prerequisites met!"

#==============================================================================
# Step 2: Create Directory Structure
#==============================================================================

print_header "Step 2: Creating Directory Structure"

print_step "Creating required directories..."

mkdir -p credentials
print_success "Created: credentials/"

mkdir -p resumes
print_success "Created: resumes/"

mkdir -p workflows
print_success "Created: workflows/"

mkdir -p n8n_data
print_success "Created: n8n_data/"

mkdir -p logs
print_success "Created: logs/"

#==============================================================================
# Step 3: Generate .env File
#==============================================================================

print_header "Step 3: Setting Up Configuration"

if [[ -f ".env" ]]; then
    print_warning ".env file already exists"
    ask_question "Do you want to regenerate it? (y/N): "
    read -r REGENERATE
    if [[ ! $REGENERATE =~ ^[Yy]$ ]]; then
        print_info "Keeping existing .env file"
    else
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        print_success "Backed up existing .env file"
        cp .env.example .env
        print_success "Created new .env file from template"
    fi
else
    cp .env.example .env
    print_success "Created .env file from template"
fi

#==============================================================================
# Step 4: Generate Encryption Key
#==============================================================================

print_step "Generating n8n encryption key..."

if command -v openssl &> /dev/null; then
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    
    # Replace encryption key in .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/your-32-character-random-hex-key-here/$ENCRYPTION_KEY/" .env
    else
        # Linux
        sed -i "s/your-32-character-random-hex-key-here/$ENCRYPTION_KEY/" .env
    fi
    
    print_success "Generated secure encryption key"
else
    print_warning "OpenSSL not found - you'll need to manually generate an encryption key"
    print_info "Generate one at: https://www.random.org/strings/"
fi

#==============================================================================
# Step 5: Configure n8n Credentials
#==============================================================================

print_step "Configuring n8n credentials..."

ask_question "Set n8n username (default: admin): "
read -r N8N_USER
N8N_USER=${N8N_USER:-admin}

ask_question "Set n8n password (default: changeme - CHANGE THIS!): "
read -r -s N8N_PASSWORD
echo
N8N_PASSWORD=${N8N_PASSWORD:-changeme}

# Update .env with n8n credentials
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^N8N_USER=.*/N8N_USER=$N8N_USER/" .env
    sed -i '' "s/^N8N_PASSWORD=.*/N8N_PASSWORD=$N8N_PASSWORD/" .env
else
    sed -i "s/^N8N_USER=.*/N8N_USER=$N8N_USER/" .env
    sed -i "s/^N8N_PASSWORD=.*/N8N_PASSWORD=$N8N_PASSWORD/" .env
fi

print_success "n8n credentials configured"

#==============================================================================
# Step 6: API Keys Setup Guide
#==============================================================================

print_header "Step 6: API Keys Setup"

echo -e "${BOLD}You need to set up these API keys:${NC}\n"

# Google Gemini API
echo -e "${BOLD}${CYAN}1. Google Gemini API (REQUIRED - FREE)${NC}"
echo -e "   ${ARROW} Visit: ${BOLD}https://makersuite.google.com/app/apikey${NC}"
echo -e "   ${ARROW} Click 'Create API Key in new project'"
echo -e "   ${ARROW} Copy the API key"
echo -e "   ${STAR} Free tier: 1,500 requests/day\n"

ask_question "Enter your Gemini API key (or press ENTER to skip): "
read -r GEMINI_KEY

if [[ -n "$GEMINI_KEY" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$GEMINI_KEY/" .env
    else
        sed -i "s/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$GEMINI_KEY/" .env
    fi
    print_success "Gemini API key configured"
else
    print_warning "Gemini API key not set - you'll need to add it manually to .env"
fi

echo ""

# Google Sheets API
echo -e "${BOLD}${CYAN}2. Google Sheets API (REQUIRED - FREE)${NC}"
echo -e "   ${ARROW} Visit: ${BOLD}https://console.cloud.google.com/${NC}"
echo -e "   ${ARROW} Create new project: 'Job Agent'"
echo -e "   ${ARROW} Enable 'Google Sheets API'"
echo -e "   ${ARROW} Create Service Account credentials"
echo -e "   ${ARROW} Download JSON key file"
echo -e "   ${ARROW} Save as: ${BOLD}credentials/google-service-account.json${NC}\n"

ask_question "Have you downloaded the service account JSON? (y/N): "
read -r HAS_SA_JSON

if [[ $HAS_SA_JSON =~ ^[Yy]$ ]]; then
    ask_question "Enter path to the JSON file: "
    read -r SA_JSON_PATH
    
    if [[ -f "$SA_JSON_PATH" ]]; then
        cp "$SA_JSON_PATH" credentials/google-service-account.json
        print_success "Service account JSON copied to credentials/"
        
        # Extract service account email
        SA_EMAIL=$(grep -o '"client_email": *"[^"]*"' credentials/google-service-account.json | cut -d'"' -f4)
        if [[ -n "$SA_EMAIL" ]]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^GOOGLE_SERVICE_ACCOUNT_EMAIL=.*/GOOGLE_SERVICE_ACCOUNT_EMAIL=$SA_EMAIL/" .env
            else
                sed -i "s/^GOOGLE_SERVICE_ACCOUNT_EMAIL=.*/GOOGLE_SERVICE_ACCOUNT_EMAIL=$SA_EMAIL/" .env
            fi
            print_success "Service account email: $SA_EMAIL"
            print_info "Share your Google Sheet with this email!"
        fi
    else
        print_error "File not found: $SA_JSON_PATH"
        print_warning "You'll need to manually copy it to credentials/"
    fi
else
    print_warning "Google Sheets not configured - set this up before running n8n"
fi

echo ""

# SerpAPI (Optional)
echo -e "${BOLD}${CYAN}3. SerpAPI (OPTIONAL - FREE Tier)${NC}"
echo -e "   ${ARROW} Visit: ${BOLD}https://serpapi.com/users/sign_up${NC}"
echo -e "   ${ARROW} Sign up (free tier: 100 searches/month)"
echo -e "   ${ARROW} Get API key from dashboard"
echo -e "   ${STAR} Recommended for better job data\n"

ask_question "Enter your SerpAPI key (or press ENTER to skip): "
read -r SERP_KEY

if [[ -n "$SERP_KEY" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^SERPAPI_KEY=.*/SERPAPI_KEY=$SERP_KEY/" .env
    else
        sed -i "s/^SERPAPI_KEY=.*/SERPAPI_KEY=$SERP_KEY/" .env
    fi
    print_success "SerpAPI key configured"
else
    print_info "SerpAPI skipped (optional - you can add it later)"
fi

#==============================================================================
# Step 7: Google Sheet Setup
#==============================================================================

print_header "Step 7: Google Sheet Configuration"

echo -e "${BOLD}Create your tracking sheet:${NC}\n"
echo -e "   ${ARROW} Visit: ${BOLD}https://sheets.google.com${NC}"
echo -e "   ${ARROW} Create new spreadsheet: 'Job Applications 2026'"
echo -e "   ${ARROW} Add these column headers in Row 1:"
echo -e ""
echo -e "   ${CYAN}Date | Company | Role | Salary | Location | JD Link |${NC}"
echo -e "   ${CYAN}Recruiter Name | Recruiter Email | Confidence | Status |${NC}"
echo -e "   ${CYAN}ATS Score | Matched Skills | Notes${NC}"
echo -e ""
echo -e "   ${ARROW} Share the sheet with your service account email"
echo -e "   ${ARROW} Give 'Editor' access\n"

ask_question "Enter your Google Sheet ID (from the URL): "
read -r SHEET_ID

if [[ -n "$SHEET_ID" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^GOOGLE_SHEET_ID=.*/GOOGLE_SHEET_ID=$SHEET_ID/" .env
    else
        sed -i "s/^GOOGLE_SHEET_ID=.*/GOOGLE_SHEET_ID=$SHEET_ID/" .env
    fi
    print_success "Google Sheet ID configured"
else
    print_warning "Sheet ID not set - add it to .env later"
fi

#==============================================================================
# Step 8: Resume Setup
#==============================================================================

print_header "Step 8: Resume Setup"

print_info "Your resume should be placed at: ${BOLD}resumes/master-resume.pdf${NC}\n"

ask_question "Do you want to copy your resume now? (y/N): "
read -r COPY_RESUME

if [[ $COPY_RESUME =~ ^[Yy]$ ]]; then
    ask_question "Enter path to your resume PDF: "
    read -r RESUME_PATH
    
    if [[ -f "$RESUME_PATH" ]]; then
        cp "$RESUME_PATH" resumes/master-resume.pdf
        print_success "Resume copied to resumes/master-resume.pdf"
    else
        print_error "File not found: $RESUME_PATH"
        print_warning "Copy your resume manually later"
    fi
else
    print_info "Don't forget to add your resume before running the workflow!"
fi

#==============================================================================
# Step 9: Job Search Parameters
#==============================================================================

print_header "Step 9: Customize Job Search"

echo -e "${BOLD}Configure your job search preferences:${NC}\n"

ask_question "Job Role (default: Software Development Engineer): "
read -r JOB_ROLE
JOB_ROLE=${JOB_ROLE:-Software Development Engineer}

ask_question "Years of Experience (default: 1.5): "
read -r JOB_EXP
JOB_EXP=${JOB_EXP:-1.5}

ask_question "Minimum Salary in LPA (default: 12): "
read -r SALARY_MIN
SALARY_MIN=${SALARY_MIN:-12}

ask_question "Maximum Salary in LPA (default: 15): "
read -r SALARY_MAX
SALARY_MAX=${SALARY_MAX:-15}

ask_question "Location (default: India): "
read -r LOCATION
LOCATION=${LOCATION:-India}

ask_question "Keywords (comma-separated, default: SDE,Full Stack,React,Node.js): "
read -r KEYWORDS
KEYWORDS=${KEYWORDS:-SDE,Full Stack,React,Node.js}

# Update .env with job preferences
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^JOB_ROLE=.*/JOB_ROLE=$JOB_ROLE/" .env
    sed -i '' "s/^JOB_EXPERIENCE=.*/JOB_EXPERIENCE=$JOB_EXP/" .env
    sed -i '' "s/^JOB_SALARY_MIN=.*/JOB_SALARY_MIN=$SALARY_MIN/" .env
    sed -i '' "s/^JOB_SALARY_MAX=.*/JOB_SALARY_MAX=$SALARY_MAX/" .env
    sed -i '' "s/^JOB_LOCATION=.*/JOB_LOCATION=$LOCATION/" .env
    sed -i '' "s/^JOB_KEYWORDS=.*/JOB_KEYWORDS=$KEYWORDS/" .env
else
    sed -i "s/^JOB_ROLE=.*/JOB_ROLE=$JOB_ROLE/" .env
    sed -i "s/^JOB_EXPERIENCE=.*/JOB_EXPERIENCE=$JOB_EXP/" .env
    sed -i "s/^JOB_SALARY_MIN=.*/JOB_SALARY_MIN=$SALARY_MIN/" .env
    sed -i "s/^JOB_SALARY_MAX=.*/JOB_SALARY_MAX=$SALARY_MAX/" .env
    sed -i "s/^JOB_LOCATION=.*/JOB_LOCATION=$LOCATION/" .env
    sed -i "s/^JOB_KEYWORDS=.*/JOB_KEYWORDS=$KEYWORDS/" .env
fi

print_success "Job search preferences configured"

#==============================================================================
# Step 10: Start Docker (Optional)
#==============================================================================

print_header "Step 10: Start the System"

ask_question "Do you want to start n8n now? (y/N): "
read -r START_NOW

if [[ $START_NOW =~ ^[Yy]$ ]]; then
    print_step "Starting Docker containers..."
    
    docker-compose up -d
    
    if [[ $? -eq 0 ]]; then
        print_success "n8n is starting up..."
        
        echo -e "\n${BOLD}Waiting for n8n to be ready...${NC}"
        sleep 5
        
        # Check if n8n is running
        if docker-compose ps | grep -q "Up"; then
            print_success "n8n is running!"
            echo -e "\n${GREEN}${BOLD}✨ Success! Your Daily Job Agent is ready! ✨${NC}\n"
            echo -e "Access n8n at: ${BOLD}${CYAN}http://localhost:5678${NC}"
            echo -e "Login with:"
            echo -e "  Username: ${BOLD}$N8N_USER${NC}"
            echo -e "  Password: ${BOLD}[hidden]${NC}\n"
        else
            print_warning "n8n may still be starting up"
            print_info "Check status with: ${BOLD}docker-compose ps${NC}"
        fi
    else
        print_error "Failed to start n8n"
        print_info "Check logs with: ${BOLD}docker-compose logs -f n8n${NC}"
    fi
else
    print_info "Skipped starting n8n"
    print_info "Start later with: ${BOLD}docker-compose up -d${NC}"
fi

#==============================================================================
# Step 11: Final Summary
#==============================================================================

print_header "Setup Complete! 🎉"

echo -e "${BOLD}What's next:${NC}\n"

echo -e "${BOLD}1. Verify your configuration:${NC}"
echo -e "   ${ARROW} Check .env file has all required keys"
if [[ ! -f "credentials/google-service-account.json" ]]; then
    echo -e "   ${CROSS} Add Google Service Account JSON to credentials/"
fi
if [[ ! -f "resumes/master-resume.pdf" ]]; then
    echo -e "   ${CROSS} Add your resume as resumes/master-resume.pdf"
fi
echo ""

echo -e "${BOLD}2. Access n8n:${NC}"
echo -e "   ${ARROW} Open: ${CYAN}http://localhost:5678${NC}"
echo -e "   ${ARROW} Login with your credentials"
echo ""

echo -e "${BOLD}3. Import the workflow:${NC}"
echo -e "   ${ARROW} Click 'Workflows' → 'Import from File'"
echo -e "   ${ARROW} Select: ${BOLD}workflows/daily-job-agent-importable.json${NC}"
echo ""

echo -e "${BOLD}4. Test the workflow:${NC}"
echo -e "   ${ARROW} Click 'Execute Workflow' to test"
echo -e "   ${ARROW} Check your Google Sheet for results"
echo ""

echo -e "${BOLD}5. Activate the schedule:${NC}"
echo -e "   ${ARROW} Toggle the workflow to 'Active'"
echo -e "   ${ARROW} It will run daily at 9 AM IST"
echo ""

echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Setup Complete! Your AI Job Agent is Ready! 🚀${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}\n"

echo -e "📚 Documentation:"
echo -e "   ${ARROW} Full guide: ${BOLD}QUICKSTART.md${NC}"
echo -e "   ${ARROW} Architecture: ${BOLD}ARCHITECTURE.md${NC}"
echo -e "   ${ARROW} Troubleshooting: ${BOLD}TROUBLESHOOTING.md${NC}"
echo ""

echo -e "💡 Need help?"
echo -e "   ${ARROW} View logs: ${BOLD}docker-compose logs -f n8n${NC}"
echo -e "   ${ARROW} Stop system: ${BOLD}docker-compose down${NC}"
echo -e "   ${ARROW} Restart: ${BOLD}docker-compose restart${NC}"
echo ""

echo -e "${YELLOW}⚠  Remember: Never commit .env or credentials/ to git!${NC}\n"

# Create a setup completion marker
touch .setup_complete
echo "$(date)" > .setup_complete

exit 0
