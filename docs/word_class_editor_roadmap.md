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
   - [ ] Replace paragraph-field editing with a real selection-aware rich text
         canvas that can edit runs, blocks, tables, images, comments, and fields
         without markdown markers.
   - [ ] Build a pagination/layout engine that understands sections, headers,
         footers, columns, floating objects, wrapping, page numbers, and ruler
         geometry.
   - [ ] Move all ribbon commands onto OpenXML command objects with undo/redo,
         current-selection state, and DOCX package mutations.
   - [ ] Implement a full style system: latent styles, based-on/next style,
         character styles, numbering styles, table styles, theme fonts, and
         document defaults.
   - [ ] Implement review as first-class OpenXML: comments, tracked
         insert/delete/move/format changes, authorship, timestamps, balloons,
         accept/reject per range, and package-level comments/revisions parts.
   - [ ] Implement references as first-class fields: TOC, hyperlinks,
         bookmarks, cross references, footnotes, endnotes, citations, captions,
         bibliography, and update-on-open behavior.
   - [ ] Implement Word-grade tables: cell selection, merge/split cells, row and
         column insert/delete, repeated headers, borders, shading, autofit,
         fixed layout, nested tables, and table styles.
   - [ ] Implement object editing: images, drawings, shapes, text boxes,
         anchors, wrapping, z-order, crop, resize handles, and grouped objects.

4. Current GUI footholds
   - [x] Style gallery: Normal, Title, Subtitle, Heading 1-6, Quote, Code,
         Caption.
   - [x] Page setup controls: margins, page size, orientation, and page break
         insertion.
   - [x] Native OpenXML document state for paragraphs, runs, tables, alignment,
         links, page breaks, and package provenance.
   - [x] Visible paragraph formatting controls in the OpenXML editor.
   - [x] Editable table cells with basic row/column sizing.

5. Better-than-Word advantages
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
