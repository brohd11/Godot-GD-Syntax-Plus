# GDScript Syntax Tags

I wanted to create this plugin to make working with preloaded classes easier. This is something that is done alot when working with plugins.

You can define tags like: "#>MyTag", as well as choosing which variable type it will apply to.
Placeing this at the end of the line, will cause every instance of that word to be highlighted in the script.

Note there is no scope checking. If you have a shadowed variable it will be highlighted as well.
