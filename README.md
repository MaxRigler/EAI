# E-AI Quick Start Guide

## What's In This Package

| File | Purpose |
|------|---------|
| `PROJECT_OVERVIEW.md` | Complete specifications - add to Antigravity Knowledge |
| `SCHEMA.sql` | Supabase database schema - run in SQL Editor |
| `PROMPT_TEMPLATES.md` | Claude prompts for each recording type |
| `ANTIGRAVITY_PROMPT.md` | Kickoff prompt + follow-up prompts for Antigravity |

---

## Setup Checklist

### 1. Supabase Setup
- [ ] Create new project at [supabase.com](https://supabase.com)
- [ ] Go to SQL Editor
- [ ] Paste and run `SCHEMA.sql`
- [ ] Note your Project URL (Settings → API)
- [ ] Note your anon key (Settings → API)

### 2. API Keys
- [ ] Anthropic API key from [console.anthropic.com](https://console.anthropic.com)
- [ ] OpenAI API key from [platform.openai.com](https://platform.openai.com) (for embeddings)

### 3. Antigravity Setup
- [ ] Open Google Antigravity
- [ ] Add `PROJECT_OVERVIEW.md` to Knowledge
- [ ] Create new workspace for E-AI
- [ ] Paste kickoff prompt from `ANTIGRAVITY_PROMPT.md`

---

## Build Order

1. **Foundation** - Project scaffold, window management, navigation
2. **Recorder View** - Audio capture, speaker assignment, UI
3. **Processing Pipeline** - Whisper, Claude, embeddings, queue
4. **Contacts** - List view, detail view, Apple Contacts sync
5. **Chat** - RAG implementation, thread management
6. **Tasks & Daily** - Task list, daily summaries, scheduling
7. **Settings & Polish** - Configuration, error handling, final touches

---

## Key Architecture Decisions

- **SwiftUI + macOS native** for future iOS reuse
- **Supabase + pgvector** for structured data + semantic search
- **Local Whisper (WhisperKit)** for cost-effective transcription
- **Claude API** for intelligent summarization
- **Dual-track audio** for automatic speaker separation
- **iPhone-sized UI** (390x844) for mobile portability

---

## Future Phases (Not in V1)

- Gmail integration
- iMessage sync
- Action execution (send emails from chat)
- iOS mobile app

The schema and architecture already account for these - they just won't be implemented initially.

---

## Questions?

Refer back to `PROJECT_OVERVIEW.md` for detailed specifications on any component.
