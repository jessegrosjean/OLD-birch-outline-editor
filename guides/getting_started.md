# Getting Started

Birch is built as an [Atom platform](https://atom.io/) package. This provides
a bunch of new features:

- Rich and well defined plugin and theme APIs.

- Cross platform (Mac, Windows, and Linux) deployment.

- Multi-file workspace with tabs, split panes, command pallet, etc.

## Installing Birch

First download and install [Atom](https://atom.io/).

The birch outliner package is not public yet so you will need to install it
manually. These are the steps to manually install Birch:

1. Download the birch-outliner-package.

2. Open Atom and choose the menu Atom > Install Shell Commands.

3. Go into the birch-outliner-package using Terminal app and do `apm install`
   followed by `apm link`. The install command installs Birch dependencies, and
   then the link command links the package into Atom's startup process.

4. Restart Atom and you should see a new File > New Outline menuy item. Use
   that to create a new outline, press "Return" to create a new item and start
   typing.

5. Once birch is installed when you open a file ending with `.oeml` in Atom it
   will be opened in the Birch outline editor.