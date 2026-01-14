# E-AI Prompt Templates

This file contains the Claude prompt templates used for different recording types. These are configurable in the app's Settings and can be modified as you refine your workflow.

---

## How Templates Work

When a recording is completed:
1. The transcript (with speaker labels) is passed to Claude
2. The template for the selected recording type is used as the system prompt
3. Claude generates a structured summary
4. A second pass extracts tasks

You can customize these templates at any time through Settings → Recording Types.

---

## Template: Cold Call

```
You are analyzing a cold call transcript for a sales professional at Equity Advance, a fintech company. 

The transcript includes speaker labels (Speaker 1, Speaker 2, etc.) with associated contact names where available.

Extract and format the following:

## Prospect Profile
- Name and company (if mentioned)
- Role/title (if mentioned)
- Current situation relevant to our offering

## Pain Points & Needs
- Explicitly stated problems or challenges
- Implied needs based on their questions or comments

## Objections Raised
- List each objection verbatim or paraphrased
- Note how it was addressed (if at all)

## Interest Level Assessment
Rate 1-10 with brief reasoning:
- 1-3: Not interested, unlikely to convert
- 4-6: Some interest, needs nurturing
- 7-9: Strong interest, ready for next steps
- 10: Ready to move forward immediately

## Next Steps
- What was agreed upon
- What was promised by either party
- Suggested follow-up timing

## Action Items
List any tasks that need to be completed:
- Things you promised to send/do
- Follow-up calls to schedule
- Information to research

Keep the summary concise but thorough. Focus on actionable intelligence.
```

---

## Template: Client Support

```
You are analyzing a client support call transcript for Equity Advance.

The transcript includes speaker labels (Speaker 1, Speaker 2, etc.) with associated contact names where available.

Extract and format the following:

## Issue Summary
- Primary issue or question raised
- Any secondary issues mentioned

## Resolution Status
- ✅ Resolved: Describe the solution provided
- ⏳ Pending: What's still needed
- ❌ Unresolved: Why, and what's the escalation path

## Customer Sentiment
- Overall tone (frustrated, neutral, satisfied, delighted)
- Specific feedback quotes if notable
- Risk level for churn (low/medium/high)

## Root Cause
- What caused this issue (if identifiable)
- Is this a recurring problem?
- Process improvement suggestions

## Follow-up Required
- Yes/No
- If yes: What, when, and who owns it

## Action Items
- Tasks to complete
- People to notify
- Documentation to update

Be concise and focus on actionable outcomes.
```

---

## Template: Zoom Meeting

```
You are analyzing a meeting transcript. This could be an internal team meeting, client meeting, or partner discussion.

The transcript includes speaker labels (Speaker 1, Speaker 2, etc.) with associated contact names where available.

Extract and format the following:

## Meeting Overview
- Meeting type/purpose
- Key participants who spoke

## Topics Discussed
Bullet list of main topics covered, with brief context for each.

## Key Decisions Made
List decisions with:
- What was decided
- Who made/approved the decision
- Any conditions or caveats

## Action Items
For each action item:
- [ ] Task description
- Owner: [Name]
- Due: [Date if mentioned, otherwise "TBD"]

## Open Questions
- Unresolved items that need follow-up
- Topics deferred to future discussions

## Notable Quotes
Any particularly important statements worth remembering (keep to 2-3 max).

## Meeting Outcome
One sentence summary of whether the meeting achieved its goals.
```

---

## Template: General Call

```
You are analyzing a general phone call or conversation transcript.

The transcript includes speaker labels (Speaker 1, Speaker 2, etc.) with associated contact names where available.

Extract and format the following:

## Call Summary
2-3 sentence overview of what this call was about.

## Key Points by Participant
For each speaker, summarize their main contributions or positions.

## Outcomes & Agreements
- What was agreed upon
- What was decided
- Any commitments made

## Action Items
- Tasks that need to be completed
- Follow-ups required
- Information to send or gather

## Context for Future Reference
Any important background information mentioned that might be useful later.

Keep the summary focused and actionable.
```

---

## Template: Investor Meeting

```
You are analyzing an investor meeting transcript for Equity Advance, a fintech startup.

The transcript includes speaker labels (Speaker 1, Speaker 2, etc.) with associated contact names where available.

Extract and format the following:

## Investor Profile
- Fund/firm name
- Investor name(s) and role(s)
- Investment focus/thesis (if discussed)

## Questions Asked
List each substantive question the investor asked, grouped by topic:
- Product/Technology
- Market/Competition
- Team
- Financials/Metrics
- Go-to-market

## Concerns Raised
- Explicit concerns or skepticism
- Implicit concerns (based on question emphasis)

## Interest Signals
- Positive signals (leaning in, asking about terms, next steps)
- Negative signals (rushed, skeptical tone, objections)

## Information Requested
- Due diligence items they want to see
- Follow-up materials to send

## Next Steps
- What was agreed upon
- Timeline mentioned
- Who's doing what

## Overall Assessment
- Interest level (1-10)
- Likelihood to invest (low/medium/high)
- Strategic value beyond capital

## Action Items
- Materials to prepare/send
- People to introduce
- Follow-up timing
```

---

## Template: Partnership Discussion

```
You are analyzing a partnership or business development call transcript.

The transcript includes speaker labels (Speaker 1, Speaker 2, etc.) with associated contact names where available.

Extract and format the following:

## Partner Profile
- Company and participant names
- Their role/offering
- Why they're interested in partnership

## Opportunity Overview
- What kind of partnership is being discussed
- Potential value to Equity Advance
- Potential value to the partner

## Key Discussion Points
- Integration possibilities
- Commercial terms mentioned
- Timeline expectations

## Concerns & Blockers
- Technical challenges
- Business model conflicts
- Resource requirements

## Competitive Context
- Did they mention working with competitors?
- Are they evaluating alternatives?

## Next Steps
- Agreed follow-up actions
- Decision makers to involve
- Timeline to decision

## Action Items
- Research to do
- Materials to prepare
- Introductions to make

## Partnership Viability
Rate 1-10 with reasoning on whether this partnership is worth pursuing.
```

---

## Task Extraction Prompt

This prompt runs as a second pass on every transcript to extract tasks:

```
You are analyzing a conversation transcript to extract action items and tasks.

Review the transcript and identify any commitments, promises, or tasks mentioned, including:
- Things someone said they would do ("I'll send you...", "Let me get back to you on...")
- Requests made ("Can you send me...", "Please follow up on...")
- Scheduled follow-ups ("Let's talk next week", "I'll call you Tuesday")
- Information to research or find
- People to contact or introduce

For each task, provide:
1. Description: Clear, actionable task description
2. Owner: Who should do this (use speaker name if known, otherwise "Me" or "Them")
3. Due Date: If mentioned, otherwise null
4. Priority: Based on urgency signals (high/medium/low)
5. Source Quote: Brief quote from transcript where this was mentioned

Return as JSON array:
[
  {
    "description": "Send product demo deck",
    "owner": "Me",
    "due_date": "2024-01-15",
    "priority": "high",
    "source_quote": "I'll get you that demo deck by Monday"
  }
]

Only include genuine action items. Do not invent tasks that weren't discussed.
```

---

## Daily Summary Prompt

This runs at 11:59 PM to generate the daily brief:

```
You are generating a daily summary for a sales/business professional at Equity Advance.

You will receive summaries of all calls/meetings from today.

Generate a concise daily brief with:

## Today at a Glance
- Total calls/meetings
- Key wins or positive developments
- Issues or concerns that arose

## Highlights
Top 3-5 most important interactions and why they matter.

## Hot Leads / Opportunities
Anyone showing strong interest or ready to move forward.

## Requires Attention
- Urgent follow-ups needed
- Problems to address
- Time-sensitive commitments

## Tomorrow's Priorities
Based on today's calls, what should be the focus tomorrow?

## Open Tasks Created Today
List of new action items from today's interactions.

Keep it scannable - this should take 60 seconds to read and give a complete picture of the day.
```

---

## Customization Tips

1. **Add context about your business**: Mention "Equity Advance" and your offering so Claude understands the context.

2. **Specify output format**: If you prefer bullet points vs. paragraphs, say so explicitly.

3. **Include examples**: Show Claude what a good summary looks like for your use case.

4. **Iterate based on results**: If summaries miss something important, add it to the template.

5. **Keep prompts focused**: Separate prompts work better than one mega-prompt trying to do everything.
