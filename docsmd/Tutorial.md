# Tutorial

This tutorial will lead you through creating a new Atom package that works
with the {OutlineEditor} API. The goal is to run a query over all open
{Outline}s and display the results in a side panel.

This tutorial focuses on the {OutlineEditor} APIs. Please refere to [Atom's
Documentation](https://atom.io/docs/latest/) for a better understanding of
writing packages in general.

Atom is designed to work with plain text files. In particular it has two core
classes for working with text files in the workspace: {TextBuffer} and
{TextEditor}. My outline editor package adds two corresponding classes for
working with outlines: {Outline} and {OutlineEditor}.

## Create new package

First create a new package with the menu item Packages > Package Generator >
Generate Atom Package. I've named my package `live-query`. To learn a lot more
about the package creating process read [Creating
Packages](https://atom.io/docs/latest/creating-a-package).

Atom should open a new window for editing the package. As you make changes to
your package you only need to View > Reload to reload Atom and have your
changes loaded. I highly recommend that as you are developing your package you
keep the [Developer Tools](https://developer.chrome.com/devtools) open so
you'll see errors and be able to track them down as you develop.

## Observer All Open Outlines

