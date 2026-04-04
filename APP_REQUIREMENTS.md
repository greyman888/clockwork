# Clockwork Application 

# Purpose

The purpose of this application to record time entries against consulting projects. 

The focus is on quick data entry and fast data retrieval for reporting purposes.

There is already a foundation of capability described in the README.md file

This file provides specific requirements.

# Data Entry

The first page will be a 'Day' page. The heading will default to today's date.

The user will have a form made up of rows. Each row will have form fields in a line. 

The first row field is a select box for entity project.

the next row field is a select box for task. this will be populated with tasks linked to that project entity.

The next row field will be start time.

They end time.

The next field will be calculated as the difference between the start and end time

the final field will be the note.

Ensure that formatting is applied to the start and end times. ensure that tabbing between fields is enabled.

At the end of the row provide a save button

# Time Entry Validation Feedback

If a time entry overlaps another time entry on the same day, indicate the overlap visually but do not prevent the user from saving the entry.

When an overlap is detected, apply a red border to the start time field and the end time field for the overlapping row.

Apply the red border effect as soon as the relevant time field loses focus.

Entries that touch at the boundary only, where one entry ends exactly when another begins, are not considered overlapping.

If the end time is earlier than the start time, apply the same red border effect to the end time field.

Allow `24:00` as a valid end time only. Treat it as the end of the day so entries such as `23:00` to `24:00` are valid and save with the correct duration.

# Week page

The purpose of the "Week" Page is to show a summary of the projects and tasks worked on for week starting on a Monday.

The layout is similar to the day page in that:
- it defaults to the current week,
- if has a row of buttons to select the date, shift left one week, select the current week, advance to the next week and shows a Week Total

Beneath the buttons is a table containing a summary of all time entries for that week
- Column 1 is project
- Column 2 is task
- Column 3 is billable
- Column 4 - 10 is Mon, Tue, Wed, Thur, Fri, Sat, Sun
- Column 5 is total

If there is both billable and non-billable time for the same project/task combination, then add a new row

In the Week table, any non-zero Mon-Sun project/task total should be displayed as a link.

When the user clicks the link, show a popup containing the notes from all of the time entries that make up that day total for that project/task/billable row.

Each time entry note should appear on a new line in the popup.

If the same note appears more than once for that day total, only show it once in the popup.

When the notes popup opens, automatically copy the popup note text to the clipboard.

Add a button on the left side of the notes popup titled `copy`.

Do not copy the popup note text when the user clicks the popup body text.

If the user clicks the `copy` button, copy the popup note text to the clipboard again.

Show a note at the bottom of the notes popup saying `(notes added to clipboard)`.

Make the notes popup wider than the default dialog width.

Do not make the Total column clickable.

The Mon-Sun column headings in the Week table should also be links.

If the user clicks a weekday heading such as `Fri`, open the Day page for that day in the currently selected week.

When the user hovers over either a weekday heading link or a non-zero day total link in the Week table, the mouse cursor should change to a pointer.

The hover background for those links should include more padding around the text so the interactive area is more obvious.

The Date selector width on the Week page should match the Project column width.

The previous, current week and next navigation control group on the Week page should match the Task column width.

Align the Bill column, the Mon-Sun columns and the Total column to the left in the Week table.

Add spacing between the Week selector column and the Bill column to match the existing Week table gaps.

Add a visible gap between the Date selector and the week navigation controls on the Week page.

If needed to keep the grid visually consistent, the same gap can be used between the Project and Task columns in the Week table.

Ensure the vertical alignment of the Week page controls and table columns is consistent.

Align the top of the Date selector and the week navigation buttons on the Week page.

Align all Week table header labels vertically so `Project`, `Task`, `Bill`, `Mon-Sun`, and `Total` sit on the same horizontal line.
