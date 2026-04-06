# Clockwork Project Guide

This is the main development reference for Clockwork. It combines the reusable
entity-component architecture intent with the current application-specific
requirements, so future coding work has one primary starting point.

## Application Summary

Clockwork is a Windows-first internal time tracking application for recording
time entries against consulting projects. It is built on top of a generalized
entity/component data management system so the application can evolve through
data definitions rather than repeated schema migrations.

The immediate product focus is fast daily data entry, fast weekly review, and
reliable reporting-oriented retrieval.

## Architectural Foundation

### Purpose of the underlying data model

The broader project goal is to provide a reusable business-data system built
around entities and components:

- The physical SQLite schema stays small and static.
- New business objects are introduced as entity kinds.
- New fields are introduced as component kinds linked to those entity kinds.
- CRUD screens can be reused across many business objects.
- Data can be queried without loading entire entity graphs.

### Core structure

- Entity kinds
- Entities
- Component kinds
- Components

### Core relationships

- Entity kinds define categories of business objects.
- Entities are instances of a given entity kind.
- Component kinds define reusable properties.
- Component membership is defined at the entity-kind level.
- All linked component kinds are optional.
- Component kinds should be displayed in creation order; no separate display
  order field is required.
- Components store values for a given entity and component kind.

### Physical storage rules

- Integer
- Real
- Text
- Entity reference, stored physically as integer

Use these storage rules:

- Keep semantic meaning separate from physical storage.
- Dates and booleans live in the integer component table.
- Enums live in the text component table.
- Entity reference components may point to any entity.
- Avoid extra physical tables for date, boolean, or enum values unless a clear
  practical benefit appears later.

### Data-definition constraints

- New business objects and fields should be created through data definitions,
  not schema migrations.
- Enum component kinds should support editable allowed options, display labels,
  and sort order.
- Entity kinds and component kinds should support soft deletion and restore.
- Soft-deleted definitions should be hidden by default in the UI.
- Entities and their stored component values may be hard-deleted.

## Current Product Requirements

## Day Page

The Day page is the first data-entry screen, should default to today, and
should be the page the application opens on at startup.

Each row is a single-line entry form containing:

- Project selector
- Task selector filtered by the selected project
- Billable flag
- Start time
- End time
- Calculated duration
- Note
- Save action

Expected behavior:

- Start and end times must be formatted consistently.
- Keyboard tabbing between fields must be supported.
- The page should support quick repeated entry rather than a heavy form flow.
- The Project field on the new Day row should use an auto-suggest interaction.
- Its suggestions should be limited to project names that start with the typed
  prefix.
- As the user types, the first matching project name should be auto-completed
  into the field with the suggested remainder selected, so typing `a` can
  become `Adore` and continuing with `d` refines the field to `Adore`.
- A note is required before a Day row can be saved.
- Pressing `Enter` in the Day row note field should submit that row.
- On Windows startup, the default app window width should be wide enough to
  show the full Day row actions, including Save and Delete, with a small
  right-side margin and without horizontal clipping.

## Day Validation Feedback

- If a time entry overlaps another time entry on the same day, show the overlap
  visually but do not block saving.
- Apply a red border to the overlapping row's start and end time inputs.
- Show the warning as soon as the relevant time field loses focus.
- Entries that only touch at the boundary are not overlapping.
- If the end time is earlier than the start time, apply the same warning style
  to the end time field.
- Allow `24:00` as a valid end time only and treat it as end-of-day.

## Week Page

The Week page shows a summary for the Monday-based week containing the selected
date.

Top controls:

- Date selector
- Previous week action
- Current week action
- Next week action
- Week total

Week table columns:

- Project
- Task
- Bill
- Mon
- Tue
- Wed
- Thur
- Fri
- Sat
- Sun
- Total

Expected behavior:

- Week rows should be ordered by project name, then task name, then billability.
- If both billable and non-billable time exist for the same project/task pair,
  render separate rows.
- Non-zero Mon-Sun totals should be clickable links.
- Clicking a non-zero day total should show a notes popup containing the unique
  notes contributing to that total, one note per line.
- When the notes popup opens, copy the note text to the clipboard.
- The popup must include a `Copy` button that copies the popup text again.
- The popup should display `(notes added to clipboard)` at the bottom.
- The popup should be wider than the default dialog width.
- The Total column should not be clickable.
- Mon-Sun headers should also be clickable links that open the Day page for that
  day in the selected week.
- Hovering over those interactive links should show a pointer cursor and a more
  obvious padded hover target.

## Setup and Summary Page

The Setup and Summary page provides a fast setup surface for projects and tasks
plus a readonly all-time summary.

Expected behavior:

- The page should be split into two columns on desktop.
- The left column should provide a compact manager for project and task
  entities.
- The manager should be based on the existing entities workflow, but should be
  specialized so the user can create, edit, and delete projects and then tasks
  without choosing a generic entity kind.
- The task manager should default to the currently selected project context and
  should filter its existing-task list by that project when possible.
- The right column should show a readonly table of all-time totals across all
  recorded days.
- The summary should include a row for every current project entity and every
  current task entity.
- Project rows should show aggregate totals for all descendant task time
  entries.
- Task rows should show totals for that task across all recorded days.
- The summary should include both billable and non-billable time.
- Zero-total projects and tasks should still appear in the summary.
- The existing right-hand summary table should be titled `Project Summary`.
- A second readonly section titled `Billability Summary` should appear directly
  underneath `Project Summary`.
- The Billability Summary should show the last six calendar months, with the
  current month in the rightmost month column.
- The Billability Summary should have eight visible data columns:
  `Title`, six three-letter month abbreviations, and `Running Average`.
- The Billability Summary should use a separate header row above the four data
  rows, and may use internal spacer columns if needed to stay consistent with
  the shared table layout system.
- The four data rows should be:
  `Billable Hours`, `Non Billable Hours`, `Total Hours Worked`, and
  `Billability %`.
- The first three rows should display numeric hours to two decimal places.
- The `Billability %` row should display percentages to one decimal place.
- The `Running Average` values for the hour rows should be the average monthly
  hours across the six months.
- The `Running Average` value for `Billability %` should be total billable
  hours divided by total worked hours across the full six-month period.
- The Billability Summary table should stay visually aligned in overall width
  with the Project Summary table by keeping the `Average` column compact, while
  still showing the header and values without clipping.
- All Billability Summary data should be read only.

## Navigation

- `Definitions` and `Entities` are development-only pages.
- They should be visible while the app is running in non-release builds.
- They should be hidden automatically in compiled release builds.

## Layout Expectations

These product-specific layout rules matter for the current application:

- The Week page date selector width should match the Project column width.
- The Week page week-navigation control group should match the Task column width.
- Bill, Mon-Sun, and Total columns should align left.
- The gap between the Week selector and Bill column should match the table gap
  logic.
- The gap between the Date selector and week navigation controls should be
  visibly intentional.
- If needed for visual consistency, that same gap may also be used between the
  Project and Task columns in the Week table.
- Vertical alignment should be consistent across top controls and table headers.
- Week table headers should sit on one horizontal line.

For the reusable layout system and verification workflow, use
[UI_DESIGN_GUIDE.md](UI_DESIGN_GUIDE.md).

## Local Definitions CLI

Clockwork includes a local definitions CLI for updating the bundled required
definitions manifest and optionally applying them to a live database.

Examples:

```bash
dart run bin/clockwork_definitions.dart show

dart run bin/clockwork_definitions.dart component-kind \
  --name billable_code \
  --display-name "Billable Code" \
  --storage-type text

dart run bin/clockwork_definitions.dart entity-kind \
  --name project_note \
  --display-name "Project Note" \
  --component name \
  --component note

dart run bin/clockwork_definitions.dart apply-required \
  --db C:\path\to\clockwork.db
```

Use `--apply-db` on the `component-kind` and `entity-kind` commands when the
live database should be updated in the same step.

## Development Principles

- Simplicity is the focus.
- The app is an internal/hobby-style project, not a public enterprise platform.
- The code should include core protections such as uniqueness checks, foreign
  key integrity, and confirmation before destructive deletes.
- The database will remain small and focused on a single user workflow.
- Target smooth 60 FPS behavior on Windows desktop.
- UI changes that could introduce layout reflow, jank, or reduced smoothness
  should be identified and discussed.
- Prefer default Flutter and Dart APIs where practical.
- Remove redundant code when possible.
- Keep the code easy for both human and AI agents to understand.
- Prefer readable statements over compressed cleverness.

## Standard Change Cycle

Use this workflow by default for new Clockwork requirements:

1. The user describes the requirement in chat.
2. Update the appropriate file in `docs/` before implementing the change.
3. Implement the requirement in code.
4. Run targeted tests for the affected area and run `flutter analyze`.
5. Launch `.\tool\run\start_windows_dev.ps1`, or hot reload/hot restart if the
   tracked app session is already running, so the user can inspect the result.
6. Report what changed in the docs, what was implemented, what was tested, and
   whether the app is ready for inspection.

### Windows Run Verification

When running the app for inspection, prefer one tracked dev-run session instead
of starting multiple copies.

Use these commands:

- Live app:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run\start_windows_dev.ps1
```

- Preview app:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run\start_windows_dev.ps1 -Preview
```

The runner script should replace any previous tracked Clockwork dev runner
before launching the next one, so old shell windows do not accumulate.

Treat the run as successful when one or both of these signals appear:

- The `flutter run` output reaches the normal startup lines such as `Built
  ...\Clockwork.exe`, `Syncing files to device Windows...`, and the `Dart VM
  Service` URL.
- A live `Clockwork.exe` process is visible in the Windows process list.

If a tracked launch is useful, capture the output to
`tool/run/flutter_run_windows.log` so the startup state can be checked without
guessing from terminal windows alone.

If the app is already running in a tracked session, prefer hot reload with `r`
or hot restart with `R` instead of launching a second instance.

Route requirement updates to these docs:

- Use `PROJECT_GUIDE.md` for product behavior, architecture, data definitions,
  workflow, and testing expectations.
- Use `UI_DESIGN_GUIDE.md` for layout rules, preview scenarios, and visual
  verification requirements.
- Use `WINDOWS_RELEASE.md` for packaging, installer, and release workflow
  changes.

## Testing Guidance

- Maintain a limited but focused set of data-integrity tests around CRUD
  behavior.
- Full UI regression suites are not required.
- Targeted widget and layout checks are appropriate when alignment, interaction,
  or deterministic preview behavior matters.

## Related Docs

- [UI_DESIGN_GUIDE.md](UI_DESIGN_GUIDE.md): shared layout rules, preview
  workflow, and visual verification steps
- [WINDOWS_RELEASE.md](WINDOWS_RELEASE.md): packaging and internal Windows
  installer workflow
