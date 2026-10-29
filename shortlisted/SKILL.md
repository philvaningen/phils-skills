---
name: shortlisted
description: Helps someone run an organized, low-stress job search — tracking a prioritized company list, applications, networking outreach, and recruiting agencies, plus using Gmail to detect status changes and draft follow-up emails. Use this whenever the person mentions job hunting, job applications, tracking their job search, following up with a recruiter or networking contact, or asks Claude to check their inbox for interview/rejection/offer news. Also trigger if they ask to set up or open their "job search tracker," even if they don't name this skill directly.
---

# Shortlisted

This skill helps someone run their job search the way a careful, organized candidate would: a ranked list of target companies, a live table of applications, a networking log with a firm follow-up cadence, and a list of recruiting agencies — plus using their Gmail to do the tedious parts (spotting status changes, drafting nudges) for them.

The core artifact is the tracker template in `assets/job-search-tracker.html` — a self-contained tracker app with its own persistent storage. Each person who uses this skill gets their own copy and their own data; nothing is shared between users.

**Everything in this skill must stay free.** The only connector it uses is Gmail, which costs nothing. Never add or suggest paid data services, paid APIs, or anything that needs a paid account or credits.

## The tracker's philosophy (from the original template this was built from)

A few principles the original creator used, worth keeping in mind since they shape the tool's behavior:

- **Rank companies by priority AND advocacy.** The priority list isn't just "companies I like" — it factors in whether there's someone who can put in a word. That's usually the highest-leverage combination.
- **The 3-business-day rule.** If a networking contact hasn't responded in 3 business days, that's the moment to send a polite nudge — not a sign to wait longer or to feel bad about following up. People are busy and forget; a nudge is a favor to them too.
- **Status tracking should be boring and simple.** Open (spotted, not applied) → Submitted → Interview → Offer/Closed. Don't over-engineer the pipeline stages.
- **Two nudges is plenty.** After two follow-ups with no reply, the tracker suggests it's fine to move on. Silence is not a verdict on the person.

## Setting someone up for the first time

1. Check whether the person already has a tracker artifact from an earlier conversation. If unsure, ask, or just create a new one — creating one is cheap and it's clearly labeled.
2. Copy `assets/job-search-tracker.html` exactly as written, save it as an HTML file, and show it to the person as an artifact using whatever tool your environment provides for that (for example, `create_file` in the Claude chat app, or the Artifact tool in Cowork). Then present it. Say something like: "Here's your tracker — it saves automatically as you use it, and only you can see your data."
3. If they already have an existing list of target companies, applications in flight, or contacts they've reached out to (e.g., pasted from an old spreadsheet, described in chat, or in an uploaded file), offer to pre-fill the tracker for them rather than making them retype everything. You can't write into `window.storage` directly from outside the artifact, so pick one:
   - **Easiest for a spreadsheet:** tell them to open the tracker, click **Import**, choose the tab, and paste their spreadsheet rows including the header row (or choose the CSV file). Column names like Company, Title/Role, Date Applied, Status, Name, Email and Notes are matched automatically, and messy statuses like "Rejected" or "phone screen" are mapped to the tracker's statuses.
   - **For anything else:** write a backup for them in the tracker's backup format and tell them to click **Import** and paste it. Format: `{"app":"job-search-tracker","version":2,"priorityList":[{"company","contact","link"}],"applications":[{"company","title","dateApplied","status","nextStep","nextDate","notes","referral"}],"networking":[{"name","company","email","lastContact","followUps","replied","notes"}],"agencies":[{"agency","recruiter","email","lastContact","notes"}],"meta":{}}`. Dates are `YYYY-MM-DD`; status is one of Open, Submitted, Interview, Offer, Closed; `followUps` is a number and `replied` is true/false. Rows don't need ids. Restoring a backup replaces everything, so only use this on a fresh tracker.
   - Or seed the same arrays directly into the `state` object in your copy of the HTML before publishing, so the data is there the first time they open it.

## What's in the tracker

- **Four tabs.** Priority List (ranked, with up/down arrows to reorder), Applications (with a colored status and a "Next step" text + date for interviews and deadlines), Network (with email, last-contact date, and reply/nudge tracking), and Agencies (agency, recruiter, email, last contact, notes).
- **"Coming up" strip.** Any application with a next-step date in the next 14 days is listed at the top, soonest first.
- **The 3-business-day rule, built in.** A contact is flagged when 3 business days have passed since the last contact with no reply. "Log nudge" records a follow-up and restarts the clock from today. "They replied" clears the flag. After two nudges the badge says it's fine to move on.
- **Backup / Import.** All data lives only in the person's browser, so remind them to click **Backup** now and then and save the copy somewhere (a file, or an email to themselves). **Import** restores a backup or adds rows from a spreadsheet.
- **Copy for Claude.** Copies the whole tracker as plain text to paste into a chat with you.
- Dates use the person's local time zone, and the layout switches to cards on a phone.

## What the tracker automates on its own

Two buttons call the Anthropic API directly (with the person's connected Gmail attached), so they work without coming back to chat:

- **"Scan Gmail for updates"** — searches Gmail for messages about the applications, proposes status changes with the supporting evidence, and lets the person accept or reject each one before anything is saved. Each application is matched by its own id, so two roles at the same company are kept apart.
- **"Draft nudge"** (appears next to any networking contact who's overdue) — drafts a short, warm follow-up and creates it as a Gmail **draft** (never auto-sent). After they send it, "I sent it — log nudge" restarts the clock.

You don't need to do anything for these to work beyond making sure the person has the Gmail connector enabled. Everything else in the tracker works without Gmail.

These buttons and the tracker's auto-save rely on artifact features in the Claude chat app (claude.ai). If they don't work where the person opened the tracker, do the same work for them in chat instead (see the next section). If auto-save isn't available, the tracker shows a banner telling them to use Backup.

## What to do when the person asks *you* directly, in chat

Sometimes it's faster for the person to just ask you rather than open the tracker and click a button. In that case, do the equivalent work yourself using your own Gmail tools and free web search:

- **"Check my email for job stuff"** / **"Did I hear back from X?"** — search Gmail (`Gmail:search_threads`, `Gmail:get_message`) for relevant threads, summarize what you find in plain language, and tell them which rows to update in their tracker (or update it live together if they have it open and can paste your summary in).
- **"Help me write a follow-up to [name] at [company]"** — draft the email inline in chat, or create it as a Gmail draft with `Gmail:create_draft` if they want it ready to send. Keep these short (under 120 words), warm, and not apologetic about following up — that's a normal, expected part of a search.
- **"Who should I reach out to at [company]?"** / **"Find me a recruiter at [company]"** — first check their Gmail for anyone at that company they've already talked to. Then suggest concrete free ways to find someone: searching LinkedIn themselves for "recruiter" or "talent acquisition" plus the company name, checking the company's careers or team page, and asking mutual connections for an intro. Don't guess or make up anyone's email address.
- **"What roles are open at [company] right now?"** — use web search to find the company's careers page and current postings; summarize a handful (title, location, link) rather than dumping a huge list, and offer to list them so the person can add them to Applications with status "Open."
- **"What should I prioritize this week?"** — you can't see the tracker on your own, so ask them to click **Copy for Claude** and paste the result (skip this if they already have). Then look at what's overdue (3+ business days since last contact with no reply), which next steps and interviews are coming up, which top-priority companies have no application or advocate yet, and what's been sitting untouched, and suggest a short, concrete plan rather than a generic pep talk.
- **When they paste a "My job search tracker" summary** — treat it as their current tracker and use it for whatever they ask. When you suggest changes, name the exact tab, row and field to update.

Important: you (in the chat loop) cannot write directly into the tracker artifact's storage — only code running inside the artifact itself can do that. So when you make a finding or draft something in chat, tell the person clearly what to do with it (paste it in, use Import, or open the tracker and hit the relevant button) rather than implying it's already saved.

## What this skill does NOT do: personal LinkedIn automation

Don't build or attempt anything that acts on someone's personal LinkedIn account — auto-connecting, auto-messaging, scraping their feed or profile views, or any browser automation that logs in as them. LinkedIn's terms of service prohibit this, and it risks the account getting flagged or suspended. If someone asks for LinkedIn automation, explain why and suggest the manual approach instead (searching LinkedIn themselves, then logging contacts in the Network tab).

## Tone

Job searching is stressful and often demoralizing. Be matter-of-fact and encouraging without being falsely cheerful — acknowledge a rejection plainly, help them move to the next thing, and never frame a lack of responses as a reflection of their worth. Don't manufacture urgency or guilt around the follow-up cadence; it's a practical habit, not a moral obligation.

## Tracker template

The tracker lives in `assets/job-search-tracker.html`, next to this file. Read it only when you're creating someone's tracker, and copy it exactly as written. It's a single self-contained page (styles, script and all), so there's nothing else to fetch or assemble.
