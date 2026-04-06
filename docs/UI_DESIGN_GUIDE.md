# UI Design Guide

Clockwork's Day and Week pages established the first reusable layout patterns for
time-entry screens. This guide captures the rules that should be reused for
future user-facing pages so layout work starts from explicit decisions instead
of visual trial-and-error.

Use this guide alongside [PROJECT_GUIDE.md](PROJECT_GUIDE.md), which contains
the main product, architecture, and application requirements context.

## Purpose

- Keep Windows desktop layouts visually consistent.
- Reuse one grid model across top controls, tables, and action areas.
- Make layout decisions easy to verify with deterministic preview data.
- Keep the verification workflow lightweight: preview, widget checks, live smoke
  pass.

## Layout Rules

### Spacing taxonomy

- Use one named standard gap for normal column separation.
- Use one named tight gap only for closely-related sub-fields such as paired
  time inputs.
- Use named exception gaps only when they represent a real boundary in the UI,
  for example `taskToBillableGap` or `billableToStartGap`.
- Do not add ad hoc `SizedBox` gaps once a grid has been established. If a gap
  matters, give it a name and reuse it.

### Labels

- When exact alignment matters, render labels as separate bold text above the
  control.
- Do not rely on built-in picker headers if they create different spacing from
  custom fields.
- Labels that are intended to align horizontally should use the same text style
  and the same label-to-control spacing.

### Grids and widths

- If top controls align to a table below, derive their widths from the same
  named column constants or combined spans.
- Prefer fixed-width `Table` layouts with explicit spacer columns for structured
  data entry and summary views.
- Keep the top control row and the table body on the same overall width when
  they are visually linked.
- Horizontal scrolling is acceptable on narrower desktop widths if alignment is
  preserved and no widgets clip or overflow.

### Form and output fields

- Read-only calculated outputs that participate in alignment should use the same
  height, border treatment, and padding as editable fields.
- Time-entry rows should keep labels in a shared header row rather than
  repeating labels on every row.
- Save and destructive actions should sit on a deliberate column or span, not
  float independently of the grid.

### Buttons and actions

- Buttons should either match a single column width or occupy an intentional
  combined span.
- Compact navigation controls should stay within the column they belong to.
- Use the accent style only for the primary action in the current context.

## Review Checklist

Check these items before considering a page visually complete:

- No yellow/black or red overflow markers appear.
- Left and right edges line up where the design says they should.
- Labels that are supposed to align share the same baseline and spacing.
- Hover targets are obvious for interactive text links and buttons.
- Pointer cursor appears for clickable text-like affordances.
- Tab order still matches the expected data-entry flow.
- Long text truncates or wraps intentionally.
- The compact desktop width still feels deliberate rather than broken.

## Preview Workflow

Run the preview pane on Windows:

```powershell
flutter run -d windows --dart-define=CLOCKWORK_UI_PREVIEW=true
```

Use the preview pane to review deterministic scenarios for:

- Day: empty state, populated state, overlap warnings, long content, `24:00`
  boundary handling, and week-to-day drill-in.
- Week: empty week, mixed billable rows, long labels, notes popup, and weekday
  navigation links.

Use the `Reset Scenario` action in the preview pane whenever you want to return
to the original fixture state.

## Verification Workflow

1. Inspect the relevant preview scenarios at `1400 x 900`.
2. Inspect the same feature at `1100 x 900`.
3. Run the targeted layout/widget checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\test\run_layout_checks.ps1
```

4. Run a live Windows smoke pass:

```powershell
flutter run -d windows
```

The live smoke pass confirms the layout still behaves correctly with the real
SQLite-backed application state.
