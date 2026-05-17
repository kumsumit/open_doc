# Open Doc

Open Doc is a modern writing workspace for proposals, reports, letters,
contracts, and research notes. It keeps the familiar power of a desktop word
processor while making the core writing flow faster, calmer, and easier to
review.

## Current draft

- Polished editor shell with print-style page layout, ruler, zoom, outline, and
  inspector panels.
- Formatting controls for type style, font, size, alignment, ink color, page
  color, tables, images, videos, checklists, and signatures.
- Search, word count, character count, reading time, comments, and change
  tracking states.
- Prototype persistence with explicit save points and restorable version
  history.
- Import flow for pasted text, real DOCX/PDF/HTML/Markdown/plain-text export,
  and share links.
- Collaboration surface with visible collaborators and document permissions.
- Templates for proposals, resumes, letters, contracts, invoices, and reports.
- Media embeds for image URLs and video links, with captions, document-page
  previews, export metadata, and version-history support.
- Current-generation writing tools: audience presets, tone modes, smart briefs,
  social summaries, action digests, source nudges, clarity scoring, and
  scanability signals.

## Run

```sh
flutter run
```

## Test

```sh
flutter test
flutter analyze
```

## Architecture

The app is being split into focused modules:

- `lib/main.dart` contains app bootstrapping and the main document studio state.
- `lib/src/ui/` contains the top bar, ribbon, editor canvas, panels, and shared controls.
- `lib/src/document/` contains document models plus import/export services.
- `lib/src/data/` contains starter content and templates.
- `docs/word_class_editor_roadmap.md` tracks the path toward a Word-class editor.
