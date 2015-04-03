# ChangeLog

## 1.7.0

- Added commands for more HTML formatting elements:

	- abbreviation
	- bold
	- citation
	- code
	- definition
	- emphasis
	- italic
	- keyboard-input
	- inline-quote
	- strikethrough
	- sample-output
	- small
	- strong
	- subscript
	- superscript
	- underline
	- variable

- Changed `onDidChange` callback to take array of Mutations.
- Fixed bug where could get stuck extending selection state.
- Fixed bug where scrollbar wouldn't theme properly on startup.
- Fixed editing problems in filtered view where items would display out of order.
- Fixed bug where deleting consecutive characters wouldn't coalecse into a single undo operation.

## 1.6.0

- Added clear button to search bar.
- Added hoist indicator to search bar.
- Restore previous expanded state after search.
- Changed selection drawing to display secondary selection on branch when in item mode.

## 1.5.0

- Added click to search on badges.
- Added syntax highlighting to search.
- Added shortcut for tags in search syntax.

	- To find all tagged items: `#`. Symantically expands to `@data-tags`
	- To find item with tagname: `#tagname`. Symantically expands to `@data-tags matches (^|,)tagname($|,)`

- Added API for attribute name shortcuts in query language.
- Fixed bug where search wasn't constrained to hoisted item.

## 1.4.0

- Added search bar (similar syntax to FoldingText)
- Fixed focus is set correctly when opening an outline.
- Fixed loading process to only display outline when fully loaded.
- Fixed some flashing that happened when clicking to set selection.

## 1.3.0

- Added indication when outline is hoisted.
- Option-Command-Up/Down to hoist/un-hoist.
- Command-Click on item handle to hoist the item.
- Dropping file on editor inserts a link to the file.
- Drag and drop no longer allows dragging item as child of itself.
- Changed root id in .bml file from `Birch.Root` to `Birch`
- Changed Shift-Click on item handle to fully expand/collapse.
- Fixed problem where editor could lose focus when hoisting.

## 1.2.1

- Added API for rendering item badges.
- Added API for rendering syntax highlighted body text.
- Added new allowed formatting elements in file format.
- Added vertical alignment guides (hide with LESS/CSS)
- Added Focus-in and Focus-out animations.
- Added "Group Items" command.
- Changed item mode selection to include item handle.
- Changed create a new child when focus-in on an item with no children.
- Changed runtime DOM structure, any custom styles likely need updating.
- Changed API to use 'get' style accessors to better match DOM conventions.
- Changed handle to Workflowy style. Its cleaner and I think will work better when using different icons to indicate different types.
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
- Started version numbers at 1.0.0 as recommended by npm.

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