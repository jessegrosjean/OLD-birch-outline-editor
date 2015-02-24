# Creating a Package

In this tutorial you will create a new Atom package that works with the
{OutlineEditor} API. Please refere to [Atom's
Documentation](https://atom.io/docs/latest/) for a better understanding of
writing packages in general.

## Create new package

Use Atom's menu item _Packages > Package Generator > Generate Atom Package_ to
create a new package. To learn a lot more about the package creating process
read [Creating Packages](https://atom.io/docs/latest/creating-a-package).

Atom will create the package and open it in a new window. As you make changes
to your package you only need to _View > Reload_ to reload Atom and have your
changes loaded. I highly recommend that as you work on your package you keep
the [Developer Tools](https://developer.chrome.com/devtools) (_View >
Developer > Toggle Developer Tools_) open.

## Subscribe to the Outline Editor Service

First you need to tell Atom that you want your package to work with the
outline editor package. We'll use Atom's [services
API](https://atom.io/docs/latest/creating-a-package #interacting-with-other-
packages-via-services) to do this.

To subscribe to the `outline-editor-service` edit your `package.json` to
include:

```json
"consumedServices": {
  "outine-editor-service": {
    "versions": {
      "^1.0.0": "consumeOutlineEditorService"
    }
  }
}
```

And then implement the callback in your package entry module:

```coffeescript
activate: (state) ->
  # Don't do anything here. Instead wait until `consumeOutlineEditorService`
  # is called before setting up our package.

consumeOutlineEditorService: (outlineEditorService) ->
  # Consume the outline editor service. This is called once both our package
  # and the outline editor package get loaded. We are return a disposable that
  # is called if/when the outline editor package is no longer availible... for
  # example if the user disables it.
  @outlineEditorService = outlineEditorService
  @subscriptions = new CompositeDisposable
  @subscriptions.add new Disposable =>
    @outlineEditorService = null
    @subscriptions = null
  # In this case our entire package depends on the outline editor, so we just
  # return all of our subscriptions here. This means if the outline editor
  # service becomes univailable then we just tear down our entire package.
  @subscriptions

deactivate: ->
  # Cleanup by disposing our subscriptions.
  @subscriptions?.dispose()
```