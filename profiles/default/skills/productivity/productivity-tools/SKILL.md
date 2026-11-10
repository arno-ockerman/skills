---
name: productivity-tools
description: "Complete productivity toolkit: Airtable, Google Workspace, Linear, Notion, Maps, PDF editing, OCR, PowerPoint, Teams pipeline. Use when managing structured data, docs, spreadsheets, project tracking, geocoding, document processing, or meeting automation."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Airtable, Google-Workspace, Linear, Notion, Maps, PDF, OCR, PowerPoint, Teams, productivity, automation]
    related_skills: [note-taking, visual-creative, github-workflow, hermes-agent]
---

# Productivity Tools — Complete Toolkit

Covers structured data (Airtable), Google ecosystem, project tracking (Linear), knowledge management (Notion), geocoding (Maps), document processing (PDF, OCR, PowerPoint), and meeting automation (Teams).

---

## Quick Selection Guide

| Task | Tool | Subsection |
|------|------|------------|
| Spreadsheet/database hybrid with API | Airtable | **1. Airtable** |
| Gmail, Calendar, Drive, Docs, Sheets | Google Workspace | **2. Google Workspace** |
| Issue tracking, projects, teams | Linear | **3. Linear** |
| Pages, databases, markdown, Workers | Notion | **4. Notion** |
| Geocode, POIs, routes, timezones | Maps (OSM/OSRM) | **5. Maps** |
| Edit PDF text/typos/titles via NL | nano-pdf | **6. nano-pdf** |
| Extract text from PDFs/scans | OCR (pymupdf, marker) | **7. OCR & Documents** |
| Create/read/edit .pptx decks | PowerPoint | **8. PowerPoint** |
| Teams meeting summaries, Graph subscriptions | Teams Pipeline | **9. Teams Meeting Pipeline** |

---

## 1. Airtable (REST API via curl)

### Auth
```bash
export AIRTABLE_API_KEY="patXXXXXXXXXXXXXX"
export AIRTABLE_BASE_ID="appXXXXXXXXXXXXXX"
```

### Common Operations
```bash
# List records
curl -s -H "Authorization: Bearer $AIRTABLE_API_KEY" \
  "https://api.airtable.com/v0/$AIRTABLE_BASE_ID/TableName"

# Create record
curl -s -X POST -H "Authorization: Bearer $AIRTABLE_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.airtable.com/v0/$AIRTABLE_BASE_ID/TableName" \
  -d '{"fields": {"Name": "Project Alpha", "Status": "Active"}}'

# Update record
curl -s -X PATCH -H "Authorization: Bearer $AIRTABLE_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.airtable.com/v0/$AIRTABLE_BASE_ID/TableName/recXXXXXXXXXXXXXX" \
  -d '{"fields": {"Status": "Done"}}'

# Filter
curl -s -H "Authorization: Bearer $AIRTABLE_API_KEY" \
  "https://api.airtable.com/v0/$AIRTABLE_BASE_ID/TableName?filterByFormula={Status}='Active'"
```

### Upsert Pattern
```bash
curl -s -X POST -H "Authorization: Bearer $AIRTABLE_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.airtable.com/v0/$AIRTABLE_BASE_ID/TableName" \
  -d '{"records": [{"fields": {"Email": "user@example.com", "Name": "John"}}, ...], "typecast": true}'
# Upsert by unique field requires separate logic: search → update or create
```

---

## 2. Google Workspace (gws CLI / Python)

### Setup
```bash
pip install google-workspace-cli
gws auth login       # OAuth flow
# Or: gws auth login --service-account key.json
```

### Gmail
```bash
gws gmail send --to user@example.com --subject "Hello" --body "Body text"
gws gmail search "from:me after:2024/01/01" --limit 10
gws gmail labels list
```

### Calendar
```bash
gws cal events list --calendar primary --time-min 2024-01-01
gws cal events create --calendar primary --summary "Meeting" --start "2024-01-15T10:00" --end "2024-01-15T11:00"
```

### Drive
```bash
gws drive files list --q "name contains 'report'"
gws drive files upload --file ./report.pdf --folder-id FOLDER_ID
gws drive permissions add --file-id FILE_ID --role reader --type anyone
```

### Docs
```bash
gws docs create --title "New Doc" --body "Content"
gws docs export --file-id DOC_ID --format pdf --output ./doc.pdf
```

### Sheets
```bash
gws sheets read --spreadsheet-id SHEET_ID --range "A1:C10"
gws sheets write --spreadsheet-id SHEET_ID --range "A1" --values "[[1,2,3],[4,5,6]]"
```

### Python Fallback
```python
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials

creds = Credentials.from_authorized_user_file("token.json")
service = build("gmail", "v1", credentials=creds)
service.users().messages().list(userId="me", q="is:unread").execute()
```

---

## 3. Linear (GraphQL + curl)

### Auth
```bash
export LINEAR_API_KEY="lin_api_XXXXXXXXXXXXXX"
```

### Common Queries
```bash
# Issues
curl -s -X POST -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  https://api.linear.app/graphql \
  -d '{"query": "{ issues(filter: {team: {name: {eq: "Engineering"}}}) { nodes { id title state { name } assignee { name } } } }"}'

# Create issue
curl -s -X POST -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  https://api.linear.app/graphql \
  -d '{"query": "mutation { issueCreate(input: {title: \"Fix bug\", teamId: \"TEAM_ID\"}) { success issue { id } } }"}'

# Teams & Projects
curl -s -X POST -H "Authorization: $LINEAR_API_KEY" \
  https://api.linear.app/graphql \
  -d '{"query": "{ teams { nodes { id name } } projects { nodes { id name state } } }"}'
```

---

## 4. Notion (API + ntn CLI)

### Setup
```bash
pip install notapi
# Or: pip install ntn-cli
ntn auth login
```

### Pages & Databases
```bash
# Create page
ntn pages create --parent DATABASE_ID --properties '{"Title": "New Task", "Status": "Todo"}'

# Query database
ntn databases query DATABASE_ID --filter '{"property": "Status", "select": {"equals": "Done"}}'

# Search
ntn search "project alpha"
```

### Python (notion-client)
```python
from notion_client import Client
notion = Client(auth=os.getenv("NOTION_TOKEN"))

# Create page
notion.pages.create(parent={"database_id": DB_ID}, properties={
    "Title": {"title": [{"text": {"content": "Task"}}]},
    "Status": {"select": {"name": "In Progress"}}
})

# Query
notion.databases.query(database_id=DB_ID, filter={"property": "Status", "select": {"equals": "Done"}})
```

---

## 5. Maps (OpenStreetMap / OSRM)

### Geocode
```bash
# Forward (address → coords)
curl -s "https://nominatim.openstreetmap.org/search?q=1600+Amphitheatre+Parkway&qformat=json&limit=1"

# Reverse (coords → address)
curl -s "https://nominatim.openstreetmap.org/reverse?lat=37.422&lon=-122.084&qformat=json"
```

### Routes (OSRM)
```bash
# Driving route
curl -s "https://router.project-osrm.org/route/v1/driving/-122.42,37.78;-122.41,37.79?overview=full&geometries=geojson"

# Multiple waypoints
curl -s "https://router.project-osrm.org/route/v1/driving/lon1,lat1;lon2,lat2;lon3,lat3?overview=full"
```

### Timezone
```bash
curl -s "https://nominatim.openstreetmap.org/search?q=Tokyo&qformat=json"
# Extract lat/lon → https://timezone.io/api/timezone/?lat=35.676&lon=139.650
```

### POIs
```bash
curl -s "https://overpass-api.de/api/interpreter?data=[out:json];node[\"amenity\"=\"restaurant\"](around:500,37.7749,-122.4194);out;"
```

---

## 6. nano-pdf (Edit PDF via NL prompts)

### Install
```bash
pip install nano-pdf
nano-pdf --version
```

### Usage
```bash
# Edit typo
nano-pdf edit input.pdf "Fix the typo on page 3: 'teh' → 'the'"

# Change title
nano-pdf edit input.pdf "Change the document title to 'Annual Report 2024'"

# Batch
nano-pdf edit input.pdf "Replace all occurrences of 'old company' with 'new company'"
```

---

## 7. OCR & Documents (pymupdf / marker-pdf)

### pymupdf (fitz) — Fast, Basic
```python
import fitz
doc = fitz.open("scan.pdf")
for page in doc:
    text = page.get_text()
    print(text)
```

### marker-pdf — Quality OCR (Layout + Tables)
```bash
pip install marker-pdf
marker_single input.pdf output_dir --langs English
```

### CLI Comparison
| Task | pymupdf | marker-pdf |
|------|---------|------------|
| Digital PDF text | ✅ Fast | ✅ |
| Scanned PDF OCR | ❌ | ✅ Best |
| Table extraction | Basic | ✅ Structured |
| Layout preservation | ❌ | ✅ |
| Speed | Very fast | Slower |

---

## 8. PowerPoint (.pptx)

### python-pptx
```python
from pptx import Presentation
from pptx.util import Inches, Pt

prs = Presentation("template.pptx")
slide = prs.slides.add_slide(prs.slide_layouts[1])
slide.shapes.title.text = "Quarterly Results"
slide.placeholders[1].text = "Revenue up 23%"

# Add image
slide.shapes.add_picture("chart.png", Inches(1), Inches(2), width=Inches(8))

prs.save("output.pptx")
```

### Templates
```python
# Use a template with predefined layouts
prs = Presentation("corporate_template.pptx")
for layout in prs.slide_layouts:
    print(layout.name)  # Pick the right one
```

---

## 9. Teams Meeting Pipeline

### Prereqs
- Microsoft Graph subscription
- Hermes CLI with teams-meeting-pipeline toolset

### Commands
```bash
# Summarize meeting
hermes teams-meeting summarize "meeting-id"

# Inspect pipeline status
hermes teams-meeting status

# Replay job
hermes teams-meeting replay "job-id"

# Manage Graph subscriptions
hermes teams-meeting subscriptions list
hermes teams-meeting subscriptions create --url "https://..." --resource "communications/onlineMeetings"
```

### Pipeline Flow
1. Webhook receives meeting event
2. Pipeline downloads recording/transcript
3. Agent summarizes with action items
4. Summary delivered to configured channel

---

## Cross-Cutting Patterns

| Pattern | Tools |
|---------|-------|
| Data → Dashboard | Airtable/Notion → Google Sheets → PowerPoint |
| Meeting → Action Items | Teams Pipeline → Linear/Notion |
| Geo Data → Visualization | Maps → Notion/Airtable → PowerPoint |
| PDF → Structured Data | nano-pdf/OCR → Airtable/Notion/Linear |

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Airtable rate limits (5 req/s) | Batch operations, add delays |
| Google Workspace token expiry | Use service account for server-to-server |
| Linear GraphQL complexity | Use fragments, paginate with `first: 50` |
| Notion API slow on large DBs | Filter early, use `page_size` |
| OSRM public API limits | Host own OSRM for production |
| nano-pdf hallucinates edits | Verify output; use for simple edits only |
| marker-pdf slow on large PDFs | Use `pymupdf` for digital text extraction |
| PowerPoint template layout mismatch | Inspect `slide_layouts` names first |
| Teams Graph subscription expiry | Renew subscriptions periodically (max ~3 days) |