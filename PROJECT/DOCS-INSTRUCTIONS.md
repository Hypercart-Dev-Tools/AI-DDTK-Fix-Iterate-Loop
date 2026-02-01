# LLM Document Management Rules

## Folder Structure
- **1-INBOX**: All new documents start here
All files should be named with Prefix of P1-P3 followed by a dash and the name of the document. This will help us to quickly understand the priority of the document and the status without opening it up. This should be reflected in the metadata of the document as well.
- **2-WORKING**: Active work only (max 3 documents)
- **3-COMPLETED**: Finished documents with completion dates
- **4-MISC**: Archives and uncertain status items

Docs outside this folder structure are:
- Changelog - please continuously udpate this file with every change

## Document Metadata (Required at Top)
```markdown
---
Author: [Name]
Date: YYYY-MM-DD
Status: [INBOX|IN PROGRESS|COMPLETED|MISC]
Goal: [Brief purpose statement]
---
```

## Core Flow
1. **Create**: Always in `1-INBOX` with format: `YYYY-MM-DD-feature-name.md`
2. **Activate**: Move to `2-IN PROGRESS` when starting. 
3. **Complete**: Move to `3-COMPLETED`. Replace prefix with `DONE-YYYY-MM-DD-`
4. **Archive**: Move to `4-MISC` if reference/uncertain status
5. Do not create any new docs unless specifically requested. 
6. Do not create summary docs unless specifically requested. 
7. Do update current project docs for checkmarks, todos, and statuses after completion. 

## File Operations
- **New docs**: Only in `1-INBOX`
- **Active work**: Only in `2-IN PROGRESS` (max 3 simultaneous)
- **Updates**: Only touch files in `2-WORKING`
- **Never delete**: Archive to `3-COMPLETED` or `4-MISC` instead

## Continuous Scanning (Every Interaction)
### Check
1. **1-INBOX** count: If >5 items → prompt triage
2. **2-IN PROGRESS** count: If >3 items → warn about context switching
3. **Stale WIP**: Flag items unchanged >7 days

Ask user if not sure how to triage certain docs.
### Triage Actions
- `1-INBOX → 2-IN PROGRESS`: User confirms active work
- `1-INBOX → 3-COMPLETED`: Already done/obsolete
- `1-INBOX → 4-MISC`: Reference or uncertain status
- `2-IN PROGRESS → 3-COMPLETED`: Work finished
- `2-IN PROGRESS → 4-MISC`: Paused indefinitely
- **Stale WIP**: Prompt to complete, archive, or cancel

## Document Standards
- Markdown format only
- One purpose per document
- Update metadata when moving folders
- Link related documents explicitly

## Forbidden
- Files in multiple locations (no copies)
- Generic names ("doc.md", "notes.md")
- Active work outside `2-IN PROGRESS`
- More than 3 items in `2-IN PROGRESS`
- Skipping metadata headers
