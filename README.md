# Project Purpose

The purpose of this project is to build a reuseable data management system built around the concept of entities and components but for business applications.

# Targeted benefits
Once intialially created, the database schema remains static. New business object are simply entities with a given 'kind'. Object properties are components of a defined 'kind' linked to those entities. 

Customisation of applications built on this data management system can be done without schema migrations. Basic forms for CRUD operations can be reused across entities.

Entity and component data across business objects can be done without needing to load entire entity information. The intent is to enable rapid data retrieval and manipulation.

# Data Structure

- Entity Kinds
- Entities
- Component Kinds
- Components

Core relationships:
- Entity kinds define the categories of business objects.
- Entities are instances of a given entity kind.
- Component kinds define reusable properties.
- Component membership is defined at the entity kind level.
- All component kinds linked to an entity kind are optional.
- Component kinds should be displayed in creation order and do not require a separate explicit display order field.
- Components store values for a given entity and component kind.

Physical storage types:
- Integer
- Real
- Text
- Entity - a special integer type used to link entities together

Key design aspects:
- The physical database schema should remain small and static.
- New business objects and new fields should be created through data definitions, not schema migrations.
- Separate component tables are kept by physical storage type for simple queries and fast targeted access.
- Dates and booleans should be stored in the integer component table.
- Enums should be stored in the text component table.
- Entity reference components may point to any entity.
- Semantic meaning should remain separate from physical storage. A component kind may be presented as a date, boolean, enum, currency, or other logical type while still being stored as integer, real, or text.
- Enum component kinds should support a defined set of allowed options, display labels, and sort order, and those options should be editable by the user.
- Additional physical tables for date, boolean, or enum data should be avoided unless a clear practical benefit appears later.
- Entity kinds and component kinds should support soft deletion rather than hard deletion.
- Soft-deleted entity kinds and component kinds should be hidden by default in the user interface.
- Soft-deleted entity kinds and component kinds should be restorable from the user interface.
- Entities and their related component values may be hard-deleted.

# Initial Requirements for this project

The first implementation will be a windows desktop app using a windows flutter theme.

A minimal landing page that welcomes the user and will form the basis of future functionality.

A side menu with two menu options:
1. Allow full CRUD operations for entity kinds and component kinds, including the linkage of component kinds to entity kinds. Component membership will be done at entity kind level. Enum options must be editable by the user.

2. Allow CRUD operations for entities in a single entity screen that includes editing all component values for that entity.

More requirements will be defined once the basic operation is complete.

# Design Principles

This framework is a hobby project. 

Not intended for wide distribution.

Simplicity is the focus.

The code does not need to be written defensively but should include core protections like uniqueness checks, foreign key integrity, and confirmation before destructive deletes.

The database size will remain small and focused on a single user.

The application should target smooth operation at 60 FPS on its intended Windows desktop environment.

UI changes that may reduce smoothness, introduce animation jank, or cause noticeable layout reflow should be identified and discussed before implementation.

Use default flutter/dart API calls where possible.

Take extra time to remove redundant code.

Keep code easy to understand by human and ai agents by not using excessively condense statements.

Aim for code comprehension.

# Tests

Create a limited set of tests that are focused on CRUD operations of data to assure data integrity.

No UI tests are required.
