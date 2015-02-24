# Outline Editor Markup Language

Outine Editor Markup Language (OEML) is subset of HTML for storing outline
data. Outline Editor uses this format to store outline data in an {HTMLDocument}
at runtime, and also uses it as a default serialization format.

At runtime this is the structure your {Outline::itemsForXPath} calls will
query. It's also the same structure that files with the .oeml file extension
will contain.

## Example OEML document

```html
<html>
  <body>
    <ul id="Birch.Root">
      <li id="my7pJv4v">
        <p>one</p>
      </li>
      <li id="mJ46JwEv">
        <p>t<b>w</b>o</p>
        <ul>
          <li id="QyLTkw4v">
            <p>three</p>
          </li>
        </ul>
      </li>
    </ul>
  </body>
</html>
```

Things to notice:

1. The basic structure is a nested unorderd list.

2. The body text content of each list item must be wrapped in a `p` element.

3. Each list item is assigned a unique and persistent ID.

4. The `ul`, `li`, `p` tag structure is fixed, you can omit or add new
   elements into the structure.

5. Formatting tags allowed inside the `p` element. Right now they are limited
   to `b`, `i`, and `u`. This set will be expanded to include `a`, `img`, and
   `span`.

6. You can extend the format to store custom data by adding attributes to the
   `li` element and eventually adding attributes to `span` formatting elements.

## Compared to Plain Text

My previous apps TaskPaper and FoldingText use plain text formatting to create
outline structure. This approach promises simplicity and portability. In some
respects this is achived: you can easily open and edit these files in any text
editor.

But in other respects the format locks in your data. The value of using an app
like TaskPaper is because it adds new features to plain text. But it is those
same features (that depend on TaskPaper's unique sytax) that get locked in.
For example it's non trivial to process a TaskPaper file outside of the
TaskPaper app and extract all the todo items. In FoldingText (with its large
set of syntax rules) "non trivial" becomes "next to impossible" if you want to
do it correctly and handle all edge cases.

This is where OEML shines and why I'm switching to it as a default format.
HTML (of which OPML is just a subset) is widely understood and deployed.
There's already a parser for it in every programming language. And an
ecosystem of other tools and technologies for creating, processing, and
storing it. It's easy to process today, and will remain easy to process long
into the future.

If your particular workflow depends on TaskPaper's or FoldingText's plain text
formatting I do plan on writing an importer/exporter. It will be lossy... for
example those formats don't have any place to store unique IDs. But generally
the basic model represented by all formats (TaskPaper, FoldingText, and OEML)
is the same and one can translate to another.

## Compared to OPML

OEML stores the same information as the
[OPML](http://en.wikipedia.org/wiki/OPML) format. The reason for using OEML
instead of OPML is because OEML is a subset of HTML and so it can more easily
take part in the larger HTML ecosystem. For example:

- You can open and view them directly in a web browser.

- The content strucuture, such as `b` tag in example above is exposed instead
  of escaped and embedded in an element attribute (what OPML does). This makes
  it possible to use [XPath](http://www.w3schools.com/xpath/xpath_syntax.asp) to
  search through the body text content structure.