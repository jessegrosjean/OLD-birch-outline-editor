# ChangeLog

## 1.2.0

- Added support for rendering item badges.
- Added support for rendering syntax highlighted body text.
- Added many new allowed formatting elements in file format.
- Added "Group Items" command.
- Changed runtime DOM structure, any custom styles likely need updating.
- Changed API to use 'get' style accessors to better match DOM conventions.
- Fixed bug in some cases of shifting items to the left.

## 1.1.0

- Added {Outline::importItem} API.
- Added {Outline::observeSelection} API.
- Added {OutlineEditorService.observeActiveEditor} API.
- Added {OutlineEditorService.observeActiveEditorSelection} API.
- Fixed edit link inserts link text if there's an empty selection.
- Fixed toggle formatting (Bold, Italic, etc) works with empty selection.
- Fixed bug where consecutive formatting tags could be lost.
- Fixed bug where cursor could jump to start of line in certain cases.

## 1.0.1

- Fixed some bugs in encoding AttributedStrings to HTML

## 1.0.0

- Documented {Selection} class.
- Fixed clearing formatting at end of line.
- Fixed dragging scroller to not modify selection.
- Fixed text caret positioning problems at text wrap boundaries.
- Started version numbers at 1.0.0 as recommadned by npm.

## 0.1.0

- Updated docs
- Added 'Edit Link' command
- Added 'Clear Formatting' command
- Shift-Cmd-C for 'code' formatting
- Added "Press Return to create a new item" message
- Drop indicator color matches theme cursor color
- Documented more {OutlineEditor} selection API

## 0.0.1 - First Release

- Every feature added
- Every bug fixed