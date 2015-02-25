# Creating a Package

Here you'll learn how to create a new Atom package that works with the Birch
outliner API to extend and add new features. As you proceed please refere to
[Atom's Documentation](https://atom.io/docs/latest/) for a better
understanding of writing packages in general. Here my focus is just on how to
integrate with Birch.

## Create new package

Use Atom's menu item _Packages > Package Generator > Generate Atom Package_ to
create a new package. I've named my package `archive-done`. To learn a lot
more about the package creating process read [Creating
Packages](https://atom.io/docs/latest/creating-a-package).

Atom will create the package and open it in a new window. As you make changes
to your package you only need to _View > Reload_ Atom to see your changes. I
highly recommend that as you work on your package you keep the [Developer
Tools](https://developer.chrome.com/devtools) (_View > Developer > Toggle
Developer Tools_) open.

## Subscribe to the Outline Editor Service

Birch is itself a package, so we need to find someway for your new package to
find and communicate with the Birch API. We'll use Atom's [services
API](https://atom.io/docs/latest/creating-a-package #interacting-with-other-
packages-via-services) to do this.

Birch defines a `birch-outline-editor-service`. To subscribe to that service
you'll need to edit your `package.json` to include:

```json
"consumedServices": {
  "birch-outine-editor-service": {
    "versions": {
      "^0.0.1": "consumeBirchOutlineEditorService"
    }
  }
},
```

And then implement the callback in your package entry module. Here's a simple
implementation:

```coffeescript
{Disposable, CompositeDisposable} = require 'atom'
...
consumeBirchOutlineEditorService: (birchOutlineEditorService) ->
  @birchOutlineEditorService = birchOutlineEditorService
  new Disposable =>
    @birchOutlineEditorService = null
```

Now your package has access to Birch API's through the {OutlineEditorService}
instance stored in `birchOutlineEditorService`. I've created an example
package to give you some ideas:

1. [Archive Done](https://github.com/FoldingText/archive-done) adds a new
   command to move all "done" items into an "Archive" section in your outline.