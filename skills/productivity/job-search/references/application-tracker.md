# Application tracker

A lightweight table so follow-ups do not slip. Keep it as a Markdown table (or a
spreadsheet if the candidate prefers). Create one on the first application and
append a row per application after.

## Schema

| Column | Meaning |
|---|---|
| Company | Employer name |
| Role | Title applied for |
| Applied | Date submitted (YYYY-MM-DD) |
| Source | Where the posting was found (referral, LinkedIn, careers page, …) |
| Status | `drafted` → `applied` → `screening` → `interviewing` → `offer` / `rejected` / `withdrawn` |
| Next action | The next step and its due date (e.g. "follow up 2026-08-25") |
| Notes | Contact name, referral, salary range, anything worth remembering |

## Example row

| Company | Role | Applied | Source | Status | Next action | Notes |
|---|---|---|---|---|---|---|
| Acme Data | Senior Data Engineer | 2026-08-11 | Referral (J. Lee) | applied | follow up 2026-08-25 | Range 140–165k; used tailored resume v2 |

## Follow-up cadence

- If no response after ~10 business days, send one polite follow-up (draft it,
  but do not send without the candidate's confirmation).
- Move stale applications (no response after ~4 weeks and one follow-up) to a
  `stalled` note rather than deleting the row; the history is useful.
