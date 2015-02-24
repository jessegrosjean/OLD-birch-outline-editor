# Getting Started

Birch is now built as a [Atom platform](https://atom.io/) package. This
provides a bunch of new features:

- Rich and well defined plugin and theme APIs.

- Multi-file workspace with tabs, split panes, etc.

- Cross platform (Mac, Windows, and Linux) deployment.

When Birch becomes a product it's likely that I'll fork and create a
customized version of Atom dedicated to outlines. But the underlying platform
will stay pretty much the same, and so for now I'm just doing development
and testing directly in Atom.

## Installing Birch

First download and install [Atom](https://atom.io/).

The birch outliner package is not public so you will need to install it
manually. These are the steps to manually install Birch:

1. Open Atom and choose the menu Atom > Install Shell Commands.

2. Download the birch-outliner-package.

3. Go into the birch-outliner-package using Terminal app and do `apm install`
   followed by `apm link`. The install command installs Birch dependencies, and
   then the link command links the package into Atoms startup process.

4. Restart Atom and you should see a new menu item File > New Outline. Use
   that to create a new outline, press "Return" to create a new item and start
   typing.

5. Once birch is installed when you open a file ending with `.oeml` in Atom it
   will be opened in the Birch outline editor.

## New UI

Birch departs from my previous apps in two respects.

First it no longer uses a purely "plain text" user interface. For example to
make text bold in FoldingText you would souround it with **'s. In Birch to
make text bold you select it and issue the Command-B "Bold" command.



## A New Approach

I've long thought that an outline model user interface was an esentail part of
the solution that I've been working toward. But in my past attempts I also
though that a pure plain text editor user interface was also esential.
Unfortunaly these two goals conflicted and my attempts to resolve the conflict
added lots of complexity to the project.

In my previous attempts (TaskPaper and FoldingText) the entire inteface was
based around a syntax highlighting plain text editor. Behind the scenes an
outline model was built and maintained based on plain text formatting rules.
Unfortunatly for every new feature a new syntax needed to be invented, and
this got out of hand. The underlying outline structure was no longer easy to
see and manipulate, and so lost its power.

The new approach that I'm taking

## A New Platform

It is a signifigant change in a number of respects, let me
first providate some background.

My interests "the goal" have been pretty consistent, if not consistently
executed throughout

The goal has always been pretty simple. Computers should be a great place to
think and process ideas, but often all this greatness is hidden behind to much

Birch is a package that extends the [Atom Text Editor](https://atom.io) to
also edit outlines.
