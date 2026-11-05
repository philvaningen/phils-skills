# Pre-filling a tracker

Read this when pre-filling a tracker from anything other than spreadsheet rows the person can paste into **Import**. You can't write into `window.storage` directly from outside the artifact, so pick one:

## Backup for them to import

Write a backup in the tracker's backup format and tell them to click **Import** and paste it. Format: `{"app":"job-search-tracker","version":2,"priorityList":[{"company","contact","link"}],"applications":[{"company","title","dateApplied","status","nextStep","nextDate","notes","referral"}],"networking":[{"name","company","email","lastContact","followUps","replied","notes"}],"agencies":[{"agency","recruiter","email","lastContact","notes"}],"meta":{}}`. Dates are `YYYY-MM-DD`; status is one of Open, Submitted, Interview, Offer, Closed; `followUps` is a number and `replied` is true/false. Rows don't need ids. Restoring a backup replaces everything, so only use this on a fresh tracker.

## Seed your copy before publishing

Put the same arrays into the `state` object in your copy of the HTML, so the data is there the first time they open it. You don't need to read the whole template: in your copy, replace any of the lines `priorityList: [],`, `applications: [],`, `networking: [],` and `agencies: [],` with the array, using the fields and formats above. Each line appears once. Write any `<` in the data as `\u003c`, because a literal `</script>` breaks the page. Change nothing else. Then confirm the copy still has only one line containing `</script>`; if it doesn't, start again from the template or use the backup route.
