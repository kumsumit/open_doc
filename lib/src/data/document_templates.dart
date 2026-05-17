const templateLibrary = {
  'Proposal': starterDocument,
  'Resume': '''
Professional summary

Write a concise summary of your role, strengths, and measurable impact.

Experience

Company name - Role title
- Led a meaningful project and describe the result.
- Improved a process, metric, or customer outcome.

Education

Degree, institution, year

Skills

Writing, analysis, planning, collaboration
''',
  'Letter': '''
Recipient name
Company or address

Dear recipient,

Use this opening paragraph to state the purpose of the letter clearly.

Add supporting details, dates, decisions, or requests in the body.

Sincerely,
Your name
''',
  'Contract': '''
Agreement overview

This agreement is between Party A and Party B and begins on the effective date.

Scope of work

1. Define responsibilities.
2. Define deliverables.
3. Define review and approval steps.

Terms

Payment, confidentiality, termination, and governing law should be reviewed by legal counsel.
''',
  'Invoice': '''
Invoice

Bill to:
Client name

| Item | Qty | Rate | Amount |
| --- | --- | --- | --- |
| Service | 1 | 0.00 | 0.00 |

Subtotal:
Tax:
Total:

Payment terms: due on receipt.
''',
  'Report': '''
Report title

Overview

Summarize the finding, decision, or project status.

Findings

- Key observation
- Supporting evidence
- Impact

Recommendations

1. Recommended action
2. Owner
3. Timeline
''',
};

const starterDocument = '''
Executive summary

Open Doc is a modern writing workspace for proposals, reports, letters, contracts, and research notes. It keeps the familiar power of a desktop word processor while making the core writing flow faster, calmer, and easier to review.

Goals:
- Create documents with print-ready layout, typography, tables, comments, and review tools.
- Keep the interface focused on the page instead of burying everyday actions.
- Make collaboration, export, and versioning visible without interrupting writing.

Project scope

This first draft covers the editor experience, document outline, search, formatting controls, comments, change tracking states, page zoom, copy, and export actions. The next production milestone can add real DOCX parsing, cloud sync, advanced rich text spans, and PDF generation.

Key milestones:
1. Build a polished editor shell with page layout and responsive panels.
2. Add document persistence and file import/export.
3. Add collaborative editing, permissions, and version history.
4. Add templates for resumes, letters, proposals, invoices, and reports.
''';
