# Welcome to FoldingText 3.0 for Atom

Write down what's in your head and use FoldingText to process those ideas: Create lists, take notes, track todo's, and more.

FoldingText is an outliner: A text editor that allows you to organize your ideas while controlling the level of detail that you want to see. Hide details to see an overview, or focus into a particular topic

FoldingText is a unique outliner. It presents a simple animated interface designed for my kids, but is built on an extensible foundation that I think can support the most demanding users.

# Creating Outlines

Once you've installed FoldingText you can create a new outline in [Atom](https://atom.io) using *File > New Outline*.

In your new outline:

- <kbd>Return</kbd> to create new items.
- <kbd>Tab</kbd> to indent items.
- <kbd>Shift-Tab</kbd> un-indent items.
- <kbd>Command-Control-Arrows</kbd> to move items: up, down, left, right. (or drag and drop with item arrow)

Use standard text formatting commands:
 
- <kbd>Command-B</kbd> to **bold** text.
- <kbd>Command-I</kbd> to *italicize* text.
- <kbd>Command-U</kbd> to <u>underline</u> text.
- <kbd>Command-Shift-K</kbd> to insert and edit links.
- <kbd>Control-C</kbd> to clear text formatting.

# Working with Outlines

FoldingText outlines have two modes: _text mode_ is for entering and editing text and _outline mode_ is for working more quickly at the outline level.

You can tell which mode you are in by looking at the text cursor. When in text mode you'll see a normal vertical line cursor. When in outline mode there is no text cursor, entire items are the smallest unit of selection.

## To enter text mode:

- <kbd>Return</kbd> to create a new item
- Press <kbd>i</kbd> or <kbd>a</kbd>.
- Press <kbd>Left</kbd> or <kbd>Right</kbd> arrow key.
- Click with mouse on text that you wish to edit.

## To exit to outline mode:

- Press <kbd>Escape</kbd>.

Since you aren't entering text keyboard shortcuts can be shorter in outline mode. For example in outline mode:

- Use <kbd>.</kbd> to expand/collapse items
- Use <kbd>t</kbd> to edit tags

## Outline Editing Commands

FoldingText has some specilized outline editing commands that are accessible through Atom's <kbd>Command-Shift-P</kbd> Command Pallet:

- _Group Items_ – Creates a new item and moves all selected items to be children of that new parent.

- _Promote Child Items_ – Moves all children of the selected item up a level.

- _Demote Trailing Sibling Items_ – Moves all sibling items after the selected item down a level so they become children of the selected item.

# Folding, Focusing, and Filtering your Outline

One of the great things about FoldingText outlines is that you can fold, focus, and filter you outline to focus on what you need at the moment.

## Folding

Folding allows you to control the level of detail that you see in your outline. Collapse items to hide their contained items. Expand to show those contained items again.

- Use <kbd>Command-.</kbd> to collapse/expand items.
- Or click the triangle next to an item to toggle folding.

## Focusing

Focusing allows you to view on part of your outline–hiding everything else. To focus in on an item use the Hoist command, to focus back out use the Un-hoist command.

- Use <kbd>Command-Option-Down</kbd> to Hoist and focus in.
- Use <kbd>Command-Option-Up</kbd> to Un-hoist and focus out.

## Filtering

Filtering allows you to run a search over the focused part of your outline. Items that don't match the search are hidden.

Try it out:

- To search type into the search field <kbd>Command-F</kbd>.
- To cancel your search <kbd>Escape</kbd> to clear the search field. <kbd>Escape</kbd> again to return focus to the outline editor.

# Using Tags, Status, and more

Use <kbd>Command-Shift-T</kbd> to edit an item's tags.

Click on an item tag to filter your outline by that tag.

# Notes for TaskPaper and FoldingText 2.0 users

Birch is big change from my previous apps.

For what I'm trying to do plain text is no longer a simplifying force. Instead it adds complexity and indirection in the interface and makes for a brittle and opaque file format.</p>


Command Based Interface

The user interface is now command driven instead of plain text driven. For example in FoldingText to create bold text you sourounded the text with **'s. In Birch you select the text and issue the "toggle-bold" command.

I've pushed on that plain text interface model because I thought it made for a simpler more direct solution. And for very simple formats it can. But as new features are added the complexity grows fast.

For example I want to add bold and italic text formatting to TaskPaper. Seems pretty strait forward, just use Markdown syntax. Except Markdown syntax isn't really simple, there are lots of edge cases, differences between flavors. And trying to document and explain it all is next to impossible.

The complexity of bold text might not seem so bad if you already know Markdown. The bigger issue is that I want to add other new features such as dates, times, durations, assigns, links nodes, links to filters, etc.

In a command based interface like Birch it becomes easy: Select what you  want to make bold and choose the "bold" command. Select what you want and assing a date using a custom date entry UI, etc.

HTML subset file format


This is a separate decision from the previous, but I'm also switching to a subset of HTML for the file format.

Previously I was using the same plain text content as both the user interface and the file format. Again, this was great for simple formats, but becomes problematic as the format becomes non-simple.

The theory with plain text is that you can edit it in any text editor. And this is true, but becomes less true the more complex the format gets. The editor might understand how to automatically apply some Markdown formatting, but it won't know how to insert or validate custom syntax that I need for representing other data types.

Plain text formats also don't have a good place to store metadata. For example I want each item in an outline to have a unique and persistent ID. This is impossible in a plain text format (that you want to remain human readable), since every line would need to include a big ugly ID.

Another big problem with plain text formats is they are hard to work with programatically. To understand the content you must write a parser. And to write a parser for a complex syntax is difficult. In 20 years it should still be simple to process through an HTML file and extract ids, tags, dates, times... but would be next to impossible if I had to invent a new plain text format for each feature.

The switch to an HTML subset makes programatic access much simpler and means Birch files can be opened and processed many years into the future.

*On the other hand*... if you don't care and still want to use plain text formatting it should (I think, but not yet implemented) be possible to do lossy (no persistent unque ids for example) conversion to/from TaskPaper or Markdown.
What is next?

Right now Birch I'm focused on the core outliner user interface. Making sure the model can support everything that I want to do. It's integration into Atom. And it's programatic API.

I'm not entirely sure where this is heading. I've been working on this since August and am having a lot of fun. But I'm not sure if Birch is a technology that I'll use to build the next versions of my apps, or if it's an app that will replace them.