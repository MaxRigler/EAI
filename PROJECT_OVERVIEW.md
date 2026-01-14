# E-AI: AI-Powered CRM for Equity Advance

## Vision

E-AI is a personal AI-powered CRM that serves as a "second brain" for business relationships. It starts with call recording and transcription, automatically extracting insights and tasks, and evolves into a comprehensive system that captures all business communications (calls, emails, iMessages) to enable intelligent querying and follow-up suggestions.

The ultimate goal: Ask questions like "Find clients who expressed interest in EquityAdvance.com but never signed up, then draft personalized re-engagement messages based on our conversation history."

---

## Tech Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Frontend/App** | Swift/SwiftUI | Native macOS + future iOS reuse (~80-90% code shared) |
| **Database** | Supabase (PostgreSQL + pgvector) | Structured data + vector embeddings for semantic search |
| **Transcription** | Local Whisper | Cost-effective at 20-50 calls/day, private, offline-capable |
| **Summarization** | Claude API | High-quality summaries with configurable prompts |
| **Contacts** | Apple Contacts.framework | Native integration, bidirectional sync |
| **Audio Storage** | Local filesystem | Cost-effective, path reference stored in Supabase |
| **Auth/Security** | macOS Keychain | API keys stored securely, no login screen needed |

---

## UI Architecture

### Window Behavior
- **Compact state:** Floating draggable bar (always accessible)
- **Expanded state:** iPhone-sized window (390 x 844 points)
- All UI designed within iPhone dimensions for future iOS port

### Navigation
- **Bottom tab bar** with 5 tabs:
  1. Recorder (default/home)
  2. Contacts
  3. Chat (center, prominent)
  4. Tasks
  5. Daily
- **Settings:** Gear icon in top corner (not a tab)
- **Drill-down:** Contact Detail accessed via Contacts list with back button

---

## Core Views

### 1. Recorder View
The primary recording interface displayed in compact/expanded state.

**Elements:**
- Record/Stop button with timer
- Audio input indicator + dropdown (mic source + system audio status)
- Speaker assignment panel (Speaker 1, 2, 3, 4, 5 — each assignable to a contact)
- Contact association (search Business Contacts, search all Apple Contacts, or Create New)
- Recording type selector (Cold Call, Client Support, Zoom Meeting, etc.)

**Behavior:**
- On Stop: Validates all speakers assigned + recording type selected
- If incomplete: Modal prompts for missing info
- If complete: Saves and processes in background (transcribe → summarize → extract tasks)

### 2. Contacts View
List of all Business Contacts (contacts that have been associated with at least one recording).

**Elements:**
- Search bar
- Scrollable contact list (name, company, last interaction date)
- Tap to drill into Contact Detail

### 3. Contact Detail View
Full record for a single business contact.

**Elements:**
- Contact info header (name, phone, email, company — pulled from Apple Contacts)
- Custom fields (business type, deal stage, tags)
- Add Comment button
- Timeline: Chronological feed of all interactions
  - Call summaries (with link to full transcript)
  - Manual comments
  - Future: Emails, iMessages
- Edit capabilities for custom fields

### 4. Chat View
Claude-style conversational interface for querying all CRM data.

**Elements:**
- Sidebar: List of saved threads + "New Chat" button
- Main area: Message thread (user messages + assistant responses)
- Input field at bottom

**Functionality:**
- RAG-powered: Queries Supabase + vector embeddings
- Can search across contacts, transcripts, summaries, tasks, notes
- Natural language queries ("Who mentioned budget concerns last month?")
- Draft generation ("Write a follow-up email to John Smith")
- Multiple saved threads (create new, revisit old)

**Future:** Action execution (send emails, create calendar events, etc.)

### 5. Tasks View
Auto-extracted and manually created tasks.

**Elements:**
- Filter tabs: All, Open, Completed
- Task list: Description, associated contact, source recording, due date, status
- Tap to mark complete or view source

**Auto-extraction:** Claude prompt scans transcripts for action items ("send proposal," "schedule follow-up," "get answer to X") and creates tasks automatically.

### 6. Daily Summaries View
Calendar-based view of all activity by day.

**Elements:**
- Date picker / calendar navigation
- Selected day shows:
  - **AI-generated daily brief** at top (aggregated summary of all calls, key outcomes, action items)
  - **Scrollable list** below: All recordings from that day (contact, type, one-line summary)
- Tap any item to view full detail

**Auto-generation:** Daily summaries run automatically at 11:59 PM.

### 7. Settings View
Configuration and system management.

**Elements:**
- **Recording Types:** Add/edit/delete types, configure prompt template for each
- **Audio Configuration:** Default mic input, system audio capture settings
- **File Storage:** Path for local audio file storage
- **Needs Attention:** Queue of failed items requiring manual review
  - Failed transcriptions
  - Failed summarizations
  - Failed contact syncs
  - Badge indicator on Settings gear when items present
- **API Configuration:** (View-only, keys stored in Keychain)

---

## User Flows

### Flow 1: Recording a Call
1. Click floating bar → Recorder view appears
2. Verify audio input (adjust via dropdown if needed)
3. Click Record → Timer starts
4. During call: Assign speakers to contacts as voices appear
5. Select recording type from dropdown
6. Click Stop
7. System validates: All speakers assigned? Recording type selected?
   - If no: Modal prompts for missing info
   - If yes: Saves recording, processes in background
8. User can immediately start another recording

### Flow 2: Background Processing (per recording)
1. Audio saved to local filesystem
2. Whisper transcribes dual-track audio → Speaker-labeled transcript
3. Claude summarizes using recording-type-specific prompt
4. Claude extracts tasks from transcript
5. All data saved to Supabase with embeddings
6. Recording status updated to "complete"
7. If any step fails 3x: Flagged in "Needs Attention"

### Flow 3: Associating a New Contact
1. During recording, tap "Assign Contact" for a speaker
2. Search shows: Business Contacts first, then option to search all Apple Contacts
3. Option C: "Create New Contact"
4. Fill in: Name, phone, email, company (optional)
5. Contact created in BOTH:
   - Supabase (as CRM Contact)
   - Apple/iCloud Contacts (for sync)
6. Speaker assigned to new contact

### Flow 4: Querying the Second Brain
1. Tap Chat tab
2. Start new thread or continue existing
3. Type natural language query: "Which prospects mentioned they're evaluating competitors?"
4. System:
   - Converts query to embedding
   - Searches vector store for relevant transcripts/summaries
   - Sends context + query to Claude
   - Returns conversational answer with relevant details
5. Follow-up: "Draft a re-engagement email for each of them"
6. Claude generates personalized drafts based on conversation history

---

## Data Model

### Core Entities

```
CRM_Contacts
├── id (UUID, primary key)
├── apple_contact_id (String, nullable — link to Apple Contacts)
├── business_type (String, nullable)
├── company (String, nullable)
├── deal_stage (String, nullable)
├── tags (Array<String>)
├── custom_fields (JSONB)
├── created_at (Timestamp)
└── updated_at (Timestamp)

Recordings
├── id (UUID, primary key)
├── file_path (String — local filesystem path)
├── duration_seconds (Integer)
├── recording_type_id (FK → Recording_Types)
├── status (Enum: processing, complete, failed)
├── created_at (Timestamp)
└── updated_at (Timestamp)

Recording_Speakers
├── id (UUID, primary key)
├── recording_id (FK → Recordings)
├── speaker_number (Integer — 1, 2, 3, 4, 5)
├── contact_id (FK → CRM_Contacts)
└── is_user (Boolean — true if this speaker is the app owner)

Transcripts
├── id (UUID, primary key)
├── recording_id (FK → Recordings, unique)
├── full_text (Text)
├── speaker_segments (JSONB — array of {speaker, start_time, end_time, text})
├── embedding (Vector(1536))
└── created_at (Timestamp)

Summaries
├── id (UUID, primary key)
├── recording_id (FK → Recordings, unique)
├── summary_text (Text)
├── prompt_template_used (Text)
├── embedding (Vector(1536))
└── created_at (Timestamp)

Tasks
├── id (UUID, primary key)
├── contact_id (FK → CRM_Contacts)
├── recording_id (FK → Recordings, nullable — source)
├── description (Text)
├── status (Enum: open, completed)
├── due_date (Date, nullable)
├── created_at (Timestamp)
└── completed_at (Timestamp, nullable)

Comments
├── id (UUID, primary key)
├── contact_id (FK → CRM_Contacts)
├── content (Text)
├── created_at (Timestamp)
└── updated_at (Timestamp)

Chat_Threads
├── id (UUID, primary key)
├── title (String)
├── created_at (Timestamp)
└── updated_at (Timestamp)

Chat_Messages
├── id (UUID, primary key)
├── thread_id (FK → Chat_Threads)
├── role (Enum: user, assistant)
├── content (Text)
└── created_at (Timestamp)

Recording_Types
├── id (UUID, primary key)
├── name (String — "Cold Call", "Client Support", etc.)
├── prompt_template (Text)
├── is_active (Boolean)
└── created_at (Timestamp)

Daily_Summaries
├── id (UUID, primary key)
├── date (Date, unique)
├── summary_text (Text)
├── embedding (Vector(1536))
└── created_at (Timestamp)
```

### Future Entities (schema-ready, not implemented in V1)

```
Emails
├── id (UUID, primary key)
├── contact_id (FK → CRM_Contacts)
├── gmail_id (String — external reference)
├── subject (String)
├── body (Text)
├── direction (Enum: inbound, outbound)
├── timestamp (Timestamp)
├── embedding (Vector(1536))
└── created_at (Timestamp)

IMessages
├── id (UUID, primary key)
├── contact_id (FK → CRM_Contacts)
├── content (Text)
├── direction (Enum: inbound, outbound)
├── timestamp (Timestamp)
├── embedding (Vector(1536))
└── created_at (Timestamp)

Actions (for future execution capabilities)
├── id (UUID, primary key)
├── chat_message_id (FK → Chat_Messages — source request)
├── action_type (Enum: send_email, send_sms, create_event, etc.)
├── payload (JSONB — action-specific data)
├── status (Enum: pending, approved, executed, failed)
├── created_at (Timestamp)
└── executed_at (Timestamp, nullable)
```

---

## Audio Architecture

### Dual-Track Recording
- **Track 1:** Microphone input (user's selected mic — desktop mic, AirPods, etc.)
- **Track 2:** System audio (captures other participants)
- Recorded as separate tracks for clean speaker separation

### Input Selection
- App queries available audio inputs via AVFoundation
- Displays current selection in Recorder view
- Dropdown allows switching mic source
- System audio capture always active alongside selected mic

### Storage
- Format: WAV or M4A (balance of quality and size)
- Location: User-configured local folder (default: ~/Documents/E-AI/Recordings/)
- Naming: `{timestamp}_{recording_type}_{contact_names}.m4a`
- Path stored in Supabase `Recordings.file_path`

---

## Transcription Pipeline

### Local Whisper Setup
- Model: whisper-large-v3 (or medium for faster processing)
- Framework: WhisperKit (optimized for Apple Silicon) or whisper.cpp
- Processing: Runs on-device, uses Metal acceleration on M-series Macs

### Speaker Handling
- Dual-track audio enables automatic speaker separation
- Track 1 transcript labeled with Speaker assignments for that track
- Track 2 transcript labeled with Speaker assignments for that track
- Transcripts merged by timestamp into unified speaker-labeled output

### Output Format
```json
{
  "full_text": "Complete transcript...",
  "segments": [
    {"speaker": 1, "start": 0.0, "end": 4.2, "text": "Hi, this is Max from Equity Advance."},
    {"speaker": 2, "start": 4.5, "end": 8.1, "text": "Hey Max, thanks for calling."},
    ...
  ]
}
```

---

## Summarization System

### Recording Type Prompts
Each recording type has a custom Claude prompt template. Examples:

**Cold Call:**
- Prospect's stated needs/pain points
- Objections raised
- Interest level (1-10)
- Next steps agreed upon
- Tasks to follow up on

**Client Support:**
- Issue reported
- Resolution provided
- Customer satisfaction indicators
- Follow-up required (Y/N)
- Tasks to follow up on

**Zoom Meeting:**
- Attendees (who spoke)
- Key decisions made
- Action items with owners
- Open questions
- Tasks to follow up on

### Task Extraction
All prompts include instruction to identify actionable items:
- "Send X to Y"
- "Follow up on Z"
- "Schedule a call about W"
- "Find answer to Q"

Extracted tasks auto-populate the Tasks table with contact association.

---

## Vector Search / RAG

### Embedding Generation
- Model: OpenAI text-embedding-3-small (or ada-002)
- Applied to: Transcripts, Summaries, Daily Summaries, future Emails/iMessages
- Stored in pgvector column

### Query Flow
1. User types question in Chat
2. Question converted to embedding
3. Supabase pgvector similarity search returns top-K relevant chunks
4. Relevant text + original question sent to Claude
5. Claude generates contextual response

### Hybrid Search
For queries mixing semantic + structured:
- Semantic: "budget concerns" → vector similarity
- Structured: "last month", "deal stage = negotiation" → SQL filters
- Combined in single Supabase query

---

## Error Handling

### Retry Strategy
- All background processes (transcription, summarization, embedding, contact sync) retry 3x
- Exponential backoff: 1s, 5s, 15s

### Failure States
After 3 failures:
- Recording status set to "failed"
- Item added to "Needs Attention" queue
- Badge appears on Settings gear icon

### Manual Resolution
Settings → Needs Attention shows:
- Failed item type and ID
- Error message
- Retry button
- Skip/dismiss option

---

## Future Roadmap (Post-V1)

### Phase 2: Email Integration
- Gmail OAuth connection
- Sync emails for Business Contacts
- Display in Contact Detail timeline
- Include in vector search/RAG

### Phase 3: iMessage Integration
- Read local iMessage database (chat.db)
- Sync messages for Business Contacts
- Display in Contact Detail timeline
- Include in vector search/RAG

### Phase 4: Action Execution
- Chat can trigger real actions (with confirmation)
- Send email via Gmail API
- Send SMS via Twilio or iMessage
- Create calendar events
- Actions table tracks requests and execution status

### Phase 5: iOS App
- Port SwiftUI views to iOS (minimal changes due to iPhone-sized design)
- Push notifications for tasks
- Mobile recording capability
- Sync via Supabase

---

## Development Notes

### Antigravity-Specific
- Add this file to Knowledge base for persistent context
- Use Agent-Assisted mode for iterative development
- Browser subagent can test the app visually

### Key Dependencies
- SwiftUI (macOS 12+)
- AVFoundation (audio capture)
- Contacts.framework (Apple Contacts)
- WhisperKit or whisper.cpp (local transcription)
- Supabase Swift SDK
- Anthropic Swift SDK (or REST API)

### API Keys Required
- Supabase: Project URL + anon key + service role key
- Claude: Anthropic API key
- OpenAI: API key (for embeddings)

Store all keys in macOS Keychain, retrieve at runtime.
