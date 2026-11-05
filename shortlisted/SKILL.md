---
name: shortlisted
description: Runs the person's own job search in an organized, low-stress way — a job search tracker with a ranked list of target companies, applications and their status, networking contacts with a 3-business-day follow-up rule, and recruiting agencies — plus Gmail to spot interview, rejection and offer news or replies, and to draft follow-up nudges. Use it whenever someone who is job hunting wants to set up, open or update their tracker; asks whether they've heard back from a company, recruiter or contact; wants a follow-up to a networking contact, referral or agency recruiter; asks who to reach out to, or what's open, at a company they're targeting; or pastes a "My job search tracker" summary or a list of applications and asks what to do next — even if they never say "tracker". Not for writing resumes or cover letters, interview practice, salary negotiation, or tracking candidates from the hiring side.
---

# Shortlisted

This skill helps someone run their job search the way a careful, organized candidate would, using their Gmail for the tedious parts (spotting status changes, drafting nudges).

The core artifact is `assets/job-search-tracker.html`, a single self-contained tracker page (styles, script and all, nothing else to fetch) with its own persistent storage. Each person gets their own copy and their own data; nothing is shared between users.

**Everything in this skill must stay free.** The only connector it uses is Gmail, which costs nothing. Never add or suggest paid data services, paid APIs, or anything that needs a paid account or credits.

## The tracker's philosophy

- **Rank companies by priority AND advocacy.** The priority list isn't just "companies I like" — it factors in whether there's someone who can put in a word. That's usually the highest-leverage combination.
- **The 3-business-day rule.** Three business days of silence from a networking contact is the moment for a polite nudge — not a sign to wait longer or to feel bad about following up. People are busy and forget; a nudge is a favor to them too.
- **Status tracking should be boring and simple.** Open (spotted, not applied) → Submitted → Interview → Offer/Closed. Don't over-engineer the pipeline stages.
- **Two nudges is plenty.** Silence is not a verdict on the person.

## Setting someone up for the first time

1. Check whether the person already has a tracker artifact from an earlier conversation. A new tracker starts empty, so if unsure, ask before creating one. To move data to a new tracker, they click **Backup** in the old one and **Import** in the new one.
2. Copy `assets/job-search-tracker.html` to a new HTML file with a shell command, without reading it, and confirm the copy is identical (for example with `cmp`). Then publish that copy unchanged as an artifact using whatever tool your environment provides. If your tool declares page capabilities, declare exactly `{"db":{},"user":{},"sample":{},"downloads":true,"mcp":{"servers":[{"server":"Gmail","tools":["search_threads","get_thread","create_draft"]}]}}`. Never change the tracker's code to suit a host: it already handles each host and shows a banner if saving isn't available. If you can't copy files, or your artifact tool needs the full text, read the template and write it out exactly as written (for example, `create_file` in the Claude chat app, or the Artifact tool in Cowork). Otherwise, don't read the template. Say something like: "Here's your tracker — it saves automatically as you use it, and only you can see your data."
3. If they already have a list of target companies, applications in flight, or contacts (e.g., pasted from an old spreadsheet, described in chat, or in an uploaded file), offer to pre-fill the tracker rather than making them retype everything. Pick one:
   - **Easiest for a spreadsheet:** tell them to open the tracker, click **Import**, choose the tab, and paste their spreadsheet rows including the header row (or choose the CSV file). Column names like Company, Title/Role, Date Applied, Status, Name, Email and Notes are matched automatically, and messy statuses are mapped to the tracker's: "phone screen" becomes Interview, "Applied" becomes Submitted, "Rejected" becomes Closed, and a row with no date or status becomes Open.
   - **For anything else:** read `references/prefill.md`. It has the backup format they can paste into **Import**, and how to seed the data into your copy of the HTML before publishing.

## What's in the tracker

- **Four tabs.** Priority List (ranked, with up/down arrows to reorder), Applications (with a colored status and a "Next step" text + date for interviews and deadlines), Network (with email, last-contact date, and reply/nudge tracking), and Agencies (agency, recruiter, email, last contact, notes).
- **"Coming up" strip.** Any application with a next-step date in the next 14 days is listed at the top, soonest first.
- **The 3-business-day rule, built in.** A contact is flagged when 3 business days have passed since the last contact with no reply. "Log nudge" records a follow-up and restarts the clock from today. "They replied" clears the flag. After two nudges the badge says it's fine to move on.
- **Agency check-ins every two weeks.** Recruiters at agencies expect regular, low-key check-ins rather than quick nudges, so an agency is flagged once 10 business days have passed since the last contact. "Log check-in" restarts that clock. Overdue contacts and agencies are counted together in the "Overdue follow-ups" number.
- **Backup / Import.** Remind them to click **Backup** now and then and save the copy somewhere (a file, or an email to themselves). If Download is blocked, use Backup's **Copy** button; Copy for Claude text can't be restored. **Import** restores a backup or adds rows from a spreadsheet.
- **Copy for Claude.** Copies the whole tracker as plain text to paste into a chat with you.
- Dates use the person's local time zone, the layout switches to cards on a phone, and the colors follow the device's light or dark setting.

## What the tracker automates on its own

Two buttons use the person's connected Gmail from inside the tracker, so they work without coming back to chat. They only need the Gmail connector enabled; everything else in the tracker works without Gmail.

- **"Scan Gmail for updates"** — searches Gmail for messages about the applications and for replies from networking contacts who haven't answered yet. It proposes status changes and "replied" marks with the supporting evidence, and lets the person accept or reject each one before anything is saved. Each row is matched by its own id, so two roles at the same company are kept apart. Auto-replies and out-of-office messages don't count as replies. If the person discards the results, the next scan looks at the same emails again.
- **"Draft nudge"** (appears next to any networking contact who's overdue) — drafts a short, warm follow-up and creates it as a Gmail **draft** (never auto-sent). After they send it, "I sent it — log nudge" restarts the clock.

These buttons and the tracker's auto-save rely on features of the artifact host. If they don't work where the person opened the tracker, do the same work for them in chat instead (see the next section). If auto-save isn't available, the tracker shows a banner telling them to use Backup.

## What to do when the person asks *you* directly, in chat

Do the equivalent work yourself using your own Gmail tools and free web search:

- **"Check my email for job stuff"** / **"Did I hear back from X?"** — search Gmail (`Gmail:search_threads`, `Gmail:get_message`) for relevant threads, summarize what you find in plain language, and tell them which rows to update in their tracker (or update it live together if they have it open and can paste your summary in).
- **"Help me write a follow-up to [name] at [company]"** — draft the email inline in chat, or create it as a Gmail draft with `Gmail:create_draft` if they want it ready to send. Keep these short (under 120 words), warm, and not apologetic about following up — that's a normal, expected part of a search.
- **"Who should I reach out to at [company]?"** / **"Find me a recruiter at [company]"** — first check their Gmail for anyone at that company they've already talked to. Then suggest concrete free ways to find someone: searching LinkedIn themselves for "recruiter" or "talent acquisition" plus the company name, checking the company's careers or team page, and asking mutual connections for an intro. Don't guess or make up anyone's email address.
- **"What roles are open at [company] right now?"** — use web search to find the company's careers page and current postings; summarize a handful (title, location, link) rather than dumping a huge list, and offer to list them so the person can add them to Applications with status "Open."
- **"What should I prioritize this week?"** — you can't see the tracker on your own, so ask them to click **Copy for Claude** and paste the result (skip this if they already have). Then look at what's overdue (contacts with 3+ business days of silence, agencies due for their two-week check-in), which next steps and interviews are coming up, which top-priority companies have no application or advocate yet, and what's been sitting untouched, and suggest a short, concrete plan rather than a generic pep talk.
- **When they paste a "My job search tracker" summary** — treat it as their current tracker and use it for whatever they ask. When you suggest changes, name the exact tab, row and field to update.

Important: you cannot write directly into the tracker artifact's storage — only code running inside the artifact itself can do that. So when you make a finding or draft something in chat, tell the person clearly what to do with it (paste it in, use Import, or open the tracker and hit the relevant button) rather than implying it's already saved.

## What this skill does NOT do: personal LinkedIn automation

Don't build or attempt anything that acts on someone's personal LinkedIn account — auto-connecting, auto-messaging, scraping their feed or profile views, or any browser automation that logs in as them. LinkedIn's terms of service prohibit this, and it risks the account getting flagged or suspended. If someone asks for LinkedIn automation, explain why and suggest the manual approach instead (searching LinkedIn themselves, then logging contacts in the Network tab).

## Tone

Job searching is stressful and often demoralizing. Be matter-of-fact and encouraging without being falsely cheerful — acknowledge a rejection plainly, help them move to the next thing, and never frame a lack of responses as a reflection of their worth. Don't manufacture urgency or guilt around the follow-up cadence; it's a practical habit, not a moral obligation.
