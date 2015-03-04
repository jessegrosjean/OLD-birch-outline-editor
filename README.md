# Birch Outline Editor

Birch is an outline editor built on the [Atom](http://atom.io) platform.

## Installing Birch

1. Install [Atom](https://atom.io/).

2. Open Atom and choose the menu Atom > Install Shell Commands.

3. Go to the birch-outline-editor package folder with Terminal app:

  - Run `apm install` to install Birch's dependencies.

  - Run `apm link` to link Birch into Atom's startup process.

4. Restart Atom and use _File > New Outline_ to create a new Outline.

## Customizing Birch

See [Customizing Atom](https://atom.io/docs/latest/customizing-atom). Birch is built on Atom so you use all the same techniques for custom themes, keymaps, and packages.

To create a package that works with Birch follow Atom's [creating a package](https://atom.io/docs/lastest/creating-a-package) instructions. Then you'll need to use the [services API](https://atom.io/docs/lastest/creating-a-package#interacting-with-other-packages-via-services) to consume the birch service.

It's a two step process:

1. In your `package.json`:

        "consumedServices": {
          "birch-outine-editor-service": {
            "versions": {
              "1": "consumeBirchOutlineEditorService"
            }
          }
        },

2. In your main module:

        {Disposable, CompositeDisposable} = require 'atom'
        ...
        consumeBirchOutlineEditorService: (birchOutlineEditorService) ->
          @birchOutlineEditorService = birchOutlineEditorService
          new Disposable =>
            @birchOutlineEditorService = null

Your package will then have access to Birch through the passed in {OutlineEditorService}. Please see these example package to get started:

- [archive-done](https://github.com/FoldingText/archive-done)
- [birch-markdown](https://github.com/FoldingText/birch-markdown)

## Birch Markup Language

Birch Markup Language (BML) is subset of HTML for storing outline data. Birch uses this format to store outline data in an {HTMLDocument} at runtime, and as a default serialization format.

### Example

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

1. The basic structure is a nested unordered list.

2. Each list item is assigned a unique and persistent ID.

3. The body text content of each list item is wrapped in a `p` element.

4. The `ul`, `li`, `p` tag structure is fixed, you can't omit or add new elements into that structure.

5. Formatting tags are allowed inside the `p` element. Right now they are limited to `a`, `b`, `i`, `s`, `code`, `span`, and `u`.

6. You can extend the format to store custom data by adding attributes to `li` elements and formatting elements.