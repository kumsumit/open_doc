# Open Doc Word-Class Roadmap

Open Doc is now moving toward a Markdown-free core: an OpenXML package model is
the document source of truth, and visual editors operate on structured
WordprocessingML concepts instead of treating Markdown as the long-term editing
format.

## Engineering Direction

- [x] Use an OpenXML-native semantic model for the editable document state.
- [x] Keep Markdown as compatibility import/export only, not as the primary
      editor model.
- [x] Represent document content as structured OpenXML blocks, runs, styles,
      tables, alignment, page breaks, and package provenance.
- [x] Prefer real OpenXML package parts and XML fragments where Word features
      need exact fidelity.

## Near-Term Priorities

1. Shared document engine
   - [x] Keep DOCX, PDF, and HTML export flowing through one
         `DocxBuiltDocument` builder.
   - [x] Add import bridges from DOCX and HTML into the same model.
   - [x] Add round-trip tests for headings, lists, tables, links, headers,
         footers, and images.
   - [x] Add OpenXML-source tests proving the model wins over legacy fallback
         text.

2. Modular editor architecture
   - [x] Keep app shell, top bar, ribbon, editor canvas, panels, import/export,
         templates, and models in separate modules.
   - [x] Move business logic out of widgets into document services as the model
         matures.
   - [x] Promote the OpenXML model into public package-style service models.

3. Word parity foundations
   - [x] Style gallery: Normal, Title, Subtitle, Heading 1-6, Quote, Code,
         Caption.
   - [x] Page setup: margins, page size, orientation, page breaks, section
         breaks, and OpenXML column metadata.
   - [x] Review: comments, suggestions, tracked insert/delete markers, and
         accept/reject flows.
   - [x] References: footnotes, endnotes, table of contents, citations, and
         bibliography placeholders.
   - [x] Layout: floating image support in the engine, wrapping metadata,
         tables with merged cells, repeated header rows, and editable table
         sizing.

4. Better-than-Word advantages
   - [x] Smart brief, action digest, citation nudges, and social summaries are
         model-aware.
   - [x] Semantic outline, source health, claim detection, and reusable document
         components are surfaced in navigation/inspector workflows.
   - [x] Export previews explain what may change before saving.

## Quality Bar

Every document feature should have:

- [x] An editor interaction.
- [x] A model representation.
- [x] DOCX export coverage.
- [x] Import or round-trip coverage when applicable.
- [x] PDF/HTML behavior where meaningful.
- [x] A focused test that proves the generated document contains real content.

## Current Baseline

- [x] Modularized app entry, UI widgets, document models, import helpers, and
      templates.
- [x] Real DOCX, PDF, and HTML export through the shared document engine.
- [x] OpenXML document model preserved in native `.odoc` packages.
- [x] Import support for DOCX, TXT, Markdown, RTF, HTML, CSV, and Open Doc.
- [x] Tests covering import, multi-format export, OpenXML source-of-truth
      export, desktop layout, and responsive behavior.
