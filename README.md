# FoldingText Outline Editor

FoldingText is an outline editor built on the [Atom](http://atom.io) platform.

## Installing FoldingText

1. Install [Atom](https://atom.io/).

2. Open Atom and choose the menu Atom > Install Shell Commands.

3. Go to the outline-editor package folder with Terminal app:

  - Run `apm install` to install FoldingText's dependencies.

  - Run `apm link` to link FoldingText into Atom's startup process.

4. Restart Atom and use _File > New Outline_ to create a new Outline.

## Customizing FoldingText

See [Hacking Atom](https://atom.io/docs/latest/hacking-atom-tools-of-the-trade). FoldingText is built on Atom so you use all the same techniques for custom themes, keymaps, and packages.

To create a package that works with FoldingText follow Atom's [creating a package](https://atom.io/docs/latest/hacking-atom-package-word-count) instructions. Then you'll need to use the [services API](https://atom.io/docs/latest/behind-atom-interacting-with-other-packages-via-services) to consume the `foldingtext-service`.

It's a two step process:

1. In your `package.json`:

        "consumedServices": {
          "foldingtext-service": {
            "versions": {
              "1": "consumeFoldingTextService"
            }
          }
        },

2. In your main module:

        {Disposable, CompositeDisposable} = require 'atom'
        ...
        consumeFoldingTextService: (foldingTextService) ->
          @foldingTextService = foldingTextService
          new Disposable =>
            @foldingTextService = null

Your package will then have access to FoldingText through the passed in {FoldingTextService}. Please see these example packages to get started:

- [archive-done](https://github.com/FoldingText/archive-done)
- [ft-markdown](https://github.com/FoldingText/ft-markdown)

## FoldingText Markup Language

FoldingText Markup Language (FTML) is subset of HTML for storing outline data. FoldingText uses this format to internally store outline data in an {HTMLDocument} at runtime, and as a default serialization format. Note: the DOM that you *see* at runtime doesn't follow this format, it's the internal model layer that uses it.

### Example

```html
<html>
  <body>
    <ul id="FoldingText">
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



5. [Inline text semantics](https://developer.mozilla.org/en-US/docs/Web/HTML/Element#Inline_text_semantics) elements are allowed inside the `p` element (including: `a`, `b`, `i`, etc.). In addition `audio`, `img`, `video`, `del`, and `ins` are allowed.

6. You can extend the format to store custom data by adding attributes to `li` elements and formatting elements.