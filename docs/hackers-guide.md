## FoldingText Hacker's Guide

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

Your package will then have access to FoldingText through the passed in {FoldingTextService}. Please see this example package to get started:

- [archive-done](https://github.com/FoldingText/archive-done)