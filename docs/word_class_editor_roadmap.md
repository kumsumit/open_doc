# Open Doc Word-Class Roadmap

Open Doc should become a document workspace that feels familiar to Microsoft Word users while surpassing it in speed, collaboration, intelligence, and developer-grade document fidelity.

## Engineering Direction

The app should move toward a rich internal document model powered by `docx_creator`, not Markdown as the long-term source of truth. Markdown remains useful for quick authoring and import/export, but Word-level fidelity needs first-class support for sections, styles, headers, footers, tables, images, shapes, comments, tracked changes, footnotes, citations, and layout metadata.

## Near-Term Priorities

1. Shared document engine
   - Keep DOCX, PDF, and HTML export flowing through one `DocxBuiltDocument` builder.
   - Add import bridges from DOCX and HTML into the same model.
   - Add round-trip tests for headings, lists, tables, links, headers, footers, and images.

2. Modular editor architecture
   - Keep app shell, top bar, ribbon, editor canvas, panels, import/export, templates, and models in separate modules.
   - Move business logic out of widgets into document services as the model matures.
   - Promote private part-file classes into public package-style modules when APIs stabilize.

3. Word parity foundations
   - Style gallery: Normal, Title, Subtitle, Heading 1-6, Quote, Code, Caption.
   - Page setup: margins, page size, orientation, columns, page breaks, section breaks.
   - Review: comments, suggestions, track changes, accept/reject by change.
   - References: footnotes, endnotes, table of contents, citations, bibliography placeholders.
   - Layout: floating images, wrapping, tables with merged cells, repeated header rows.

4. Better-than-Word advantages
   - Smart brief, action digest, citation nudges, and social summaries should become model-aware.
   - Add semantic outline, source health, claim detection, and reusable document components.
   - Make export previews explain what may change before saving.

## Quality Bar

Every document feature should have:

- An editor interaction.
- A model representation.
- DOCX export coverage.
- Import or round-trip coverage when applicable.
- PDF/HTML behavior where meaningful.
- A focused test that proves the generated document contains real content.

## Current Baseline

- Modularized app entry, UI widgets, document models, import helpers, and templates.
- Real DOCX, PDF, and HTML export through `docx_creator`.
- Import support for DOCX, TXT, Markdown, RTF, HTML, and CSV.
- Tests covering import, multi-format export, desktop layout, and responsive behavior.
