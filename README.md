# GDScript Syntax Plus

Originally, this plugin was meant to make plugins a bit nicer to work on by providing highlighting to preloaded classes. I have since solved this problem with [Plugin Exporter](https://github.com/brohd11/Godot-Plugin-Exporter). However, I have expanded on the capabilities, so it is still useful for other things.

[Youtube Walkthrough](https://youtu.be/BasfB5nXlV0)

### Version 0.8.0

Currently tested with 4.4 and 4.5. I do use context menu plugins which were introduced in 4.4, so earlier version support may be added with some reduced features. 

#### Automatic Highlights

In version 0.8.0, I have added a few new highlight types. The list right now is:
- CONSTANT_CASE can be used with const
- PascalCase can be used with const or vars, onready or export
- Onready only applies to onready var that start with lowercase or underscore
- Member will apply to any thing defined in the script or underlying class, configurable
- Member access will change the color when accessing a value of something, var.member_access

Member highlighting is the same as the new highlighting made available in 4.5. All members of the script and class will be the blue member access color. I do find this to be a bit hard to read though, so I have added the option to disable it entirely or revert back to the 4.4 and below way where script members are white and class members are colored.

In addition to the above, I have added an option to change the member access color. So you could, for example, have local variables white, member variables another color, and the member access of both a third color. It can help break up the lines a bit.

#### Tags

You can also define tags like: "#>MyTag", as well as choosing which variable type it will apply to.
Placeing this at the end of the line, will cause every instance of that word to be highlighted in the script.

Note there is no scope checking. If you have a shadowed variable it will be highlighted as well.

Context menu entries are added to lines that have a valid keyword for your tags.

![syn_tag_example](https://github.com/user-attachments/assets/97a7f124-00f6-4f55-b00a-60f13914a6bf)

Use the config window under Project -> Tools to set the desired tags, keywords and colors.

![syn_tag_config](https://github.com/user-attachments/assets/b763622d-15d5-4b43-a47d-2ae2685c075a)

#### Performance

I had a hard time trying to find a way to extend the regular GDScript highlighter. The method I ended up using was to create a dummy code edit where the current script editor text is copied to and then has a standard GDScript highlighter ran on it. From there I take that information and run my regexs and methods on that data. It works great because I do not need to recreate the GDScript rules, but it does have some overhead.

It is not terrible performance, I have made some decent optimizations, but it will start to be noticable on larger files. This is due to modifying the dummy code edit. As the scripts get larger, this step takes more and more time. Realistically, this should not be too much of an issue. I have found even at 10K lines, it was usable for me, this is far larger than I will need. However, I can't say how it will perform on older or slower machines, at larger file sizes.