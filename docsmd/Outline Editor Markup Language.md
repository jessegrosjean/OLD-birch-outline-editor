Outine Editor Markup Language (oeml) is subset of HTML for storing outline
data. Outline Editor uses this format to store outline data in an HTMLDocument
at runtime, and also as a default serialization format.



- one
- t**w**o
  - three

Is stored like this:

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


Generally you shouldn't need to know
# about underlying HTMLDocument

 using a
# restricted (ftml) set of HTML elements. Each item's data is stored in a `LI`
# and each items body text is wrapped in a `P` in that `LI`. This format is
# also used by default when saving outlines to disk.
#
# You should not manipulate this structure directly, but you can
# query it using {::evaluateXPath}.
