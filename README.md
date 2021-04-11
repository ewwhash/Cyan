**Advanced bootloader for OpenComputers**
## Installation

For **OpenOS**, just run this command:

```
pastebin run irfixAqG
```
Or if you have a problem with accessing pastebin.com use this:
```
wget -fq https://raw.githubusercontent.com/BrightYC/Cyan/master/installer.lua; installer.lua
```

For **MineOS**, you need to find app with name `Cyan BIOS`.
## Lua 5.3
Lua REPL with implemented functions:

* os.sleep([timeout: number])
* proxy(componentName: string): component proxy or nil
* read(lastInput: string or nil): string or nil
* print(...)

## Internet boot
Executes file from specified URL

## Whitelist access
Prevents booting, for example, if computer stays in some private places.
To boot, it needs some input from user that defined in whitelist (It can be edited manually in file cyan.bin)

Example of the whitelist: 
cyan={{'hohserg',"fingercomp",'Saghetti',n=3}}
If we need asking prompt:
cyan={{'hohserg','fingercomp'},1}
(If the second index of the table is true - then Cyan will be asking each time when loading OS) 

## How to build own Cyan BIOS?
Just run compress.lua (before that minify the code, for example here: https://mothereff.in/lua-minifier) and make sure that minified.lua file stored in the same folder that compress.lua

## Images/Videos

https://www.youtube.com/watch?v=89K8mWFEJKw
![](https://i.imgur.com/WWiX2tQ.png)
![](https://i.imgur.com/pnFC0cO.png)
![](https://i.imgur.com/6QXw6LX.png)
![](https://i.imgur.com/Yi7v2n2.png)
