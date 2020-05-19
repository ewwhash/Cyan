![](https://i.imgur.com/hxUBX72.png)
**Advanced bootloader with Lua REPL, protected access and cool interface (OpenComputers)**

## Installation

For **OpenOS**, just run this command(You are need an internet card to do this):

```
wget -fq https://raw.githubusercontent.com/BrightYC/Cyan/master/installer.lua && installer.lua
```

For **MineOS**, you need to find app with name `Cyan BIOS`. That's it!
## Lua 5.3
This function is the basic Lua 5.3 interpreter with the following functions:

* os.sleep([timeout: number]) -- Basic delay (You can interrupt this via CTRL+ALT+C)
* proxy(componentName: string): component proxy or nil -- Like component.eeprom in OpenOS/MineOS
* print(...) -- Very basic print

## Internet boot
This function loads the specified file by URL and executes it

## Rename/Format
This function renames/formats the selected file system

## Images/Videos

![](https://i.imgur.com/vNztz3h.png)
