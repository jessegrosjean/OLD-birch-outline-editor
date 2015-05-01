# FoldingText Markup Language

FoldingText Markup Language (FTML) is subset of HTML for storing outline data. FoldingText uses this format to internally at runtime, and as the default file format.

## Example

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

1. The structure is a nested unordered list.

2. Each list item is assigned a unique and persistent ID.

3. The body text content of each list item is wrapped in a `p` element.

4. The `ul`, `li`, `p` tag structure is fixed, you can't omit or add new elements into that structure.

5. [Inline text semantics](https://developer.mozilla.org/en-US/docs/Web/HTML/Element#Inline_text_semantics) elements are allowed inside the `p` element (including: `a`, `b`, `i`, etc.). In addition `audio`, `img`, `video`, `del`, and `ins` are allowed.

6. You can extend the format to store custom data by adding data attributes to `li` elements and formatting elements.