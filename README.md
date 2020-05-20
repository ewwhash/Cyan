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
This function downloads the specified file by URL and executes it.

## Rename/Format
This functions renames/formats the selected file system.

## Pasword access
Password access for EEPROM without request an password at boot is useless(Password gives weak security, because any player can reflsash EEPROM/format all drives or something. For very strong security use computer.addUser()) but both they is not bad.  
For sure, password is stored in unencrypted form, i can't put true hash library, i have no space for this. But, password is protected from reading on the computer that has EEPROM installed, eeprom is redirecting eeprom.get() call to eeprom.getData(). So, if you do not give your EEPROM to someone, you can not worry about security.

## Images/Videos

![](https://i.imgur.com/WWiX2tQ.png)
![](https://i.imgur.com/6IxcZOW.png)
![](https://i.imgur.com/6QXw6LX.png)
![](https://i.imgur.com/Yi7v2n2.png)