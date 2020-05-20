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

* os.sleep([timeout: number]) -- Basic delay (You can interrupt this via CTRL+ALT+C).
* proxy(componentName: string): component proxy or nil -- Like component.eeprom in OpenOS/MineOS.
* print(...) -- Very basic print.

## Internet boot
This function loads the specified file by URL and executes it.

## Rename/Format
This functions renames/formats the selected file system.

## Pasword access
For sure, password is stored in unencrypted form, i can't put true hash library, i have no space for this. But, password is protected from reading on the computer that has EEPROM installed, eeprom is redirecting eeprom.get() call to eeprom.getData(). So, if you do not give your EEPROM to someone, you can not worry about security.

## Images/Videos

![](https://i.imgur.com/vNztz3h.png)
