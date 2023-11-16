# Vimscript libraries

Various Vimscript libraries that can be imported as a Git submodule into
Vimscript plugin projects.

## How to use

Add this repository as a submodule of your plugin, and store it in the
`autoload/libs` folder of your plugin:

```sh
git submodule add git@github.com:cdelledonne/vim-libs.git autoload/libs
```

Then use in your plugin as:

```vim
let argparser = libs#argparser#New()
```
