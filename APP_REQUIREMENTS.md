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