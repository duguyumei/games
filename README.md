# HelloTaiwuMod

Minimal Taiwu mod scaffold for the CrossOver Steam installation on this machine.

## Build

```bash
DOTNET_ROOT=/Users/cc/Documents/taiwu/.dotnet /Users/cc/Documents/taiwu/.dotnet/dotnet build /Users/cc/Documents/taiwu/HelloTaiwuMod/Source/HelloTaiwuMod.csproj -c Release
```

Build output goes to:

```text
/Users/cc/Documents/taiwu/HelloTaiwuMod/Plugins/
```

## Install

Copy the `HelloTaiwuMod` folder to the game's local mod directory:

```text
/Users/cc/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/The Scroll Of Taiwu/Mod/HelloTaiwuMod
```

