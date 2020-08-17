**Advanced bootloader with Lua REPL, protected access and cool interface (OpenComputers)**
## Installation

For **OpenOS**, just run this command(You are need an internet card to run this):

```
wget -fq https://raw.githubusercontent.com/BrightYC/Cyan/master/installer.lua && installer.lua
```

For **MineOS**, you need to find app with name `Cyan BIOS`.
## Lua 5.3
This function is the basic Lua 5.3 interpreter with the following functions:

* os.sleep([timeout: number])
* proxy(componentName: string): component proxy or nil -- Like component.eeprom in OpenOS/MineOS.
* read(lastInput: string or nil): string or nil -- Very basic read, like io.read()
* print(...)

## Internet boot
This function downloads the specified file by URL and executes it.

## Rename/Format
This functions renames/formats the selected file system.

## Whitelist access
This feature can prevent untrusted boot (Require input from trusted user)

## How to build own Cyan BIOS?
You need this lzss library, which is here: https://github.com/BrightYC/Other/blob/master/lzss.lua   
To compress, use this code: https://raw.githubusercontent.com/BrightYC/Cyan/master/compress.lua  
It can run natively, in OpenComputers, or whatever the lua code can interpret.  
And you need to place uncompressed code with name "minified.lua"  

## Images/Videos

https://www.youtube.com/watch?v=89K8mWFEJKw
![](https://i.imgur.com/WWiX2tQ.png)
![](https://i.imgur.com/pnFC0cO.png)
![](https://i.imgur.com/6QXw6LX.png)
![](https://i.imgur.com/Yi7v2n2.png)
