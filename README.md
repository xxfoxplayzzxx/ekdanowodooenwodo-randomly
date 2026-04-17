# Cmdr Executor - GitHub-Based Command System for Roblox

A complete Roblox command system that can be loaded directly from GitHub via an executor like Delta.

## 🚀 Quick Start

### Load into your game:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/xxfoxplayzzxx/ekdanowodooenwodo-randomly/main/init.lua"))()
```

### Usage:
- Press **F2** to open the command interface
- Type commands and press Enter
- Access the API via the global `Cmdr` variable

## 📁 Repository Structure

```
cmdr-executor/
├── init.lua                          # Main loader (execute this)
├── src/
│   ├── Shared/
│   │   ├── Util.lua                  # Utility functions
│   │   ├── Registry.lua              # Type & command registry
│   │   ├── Dispatcher.lua            # Command execution
│   │   ├── Command.lua               # Command context
│   │   └── Argument.lua              # Argument parsing
│   ├── CmdrInterface/
│   │   ├── init.lua                  # Interface loader
│   │   ├── Window.lua                # Main window
│   │   └── AutoComplete.lua          # Autocomplete system
│   ├── Types/
│   │   ├── Primitives.lua            # string, number, boolean, integer
│   │   ├── Player.lua                # Player type with shorthands
│   │   ├── PlayerId.lua              # Player ID type
│   │   ├── Team.lua                  # Team types
│   │   ├── BrickColor.lua            # BrickColor types
│   │   ├── Color3.lua                # Color3 types
│   │   ├── Vector.lua                # Vector2/Vector3 types
│   │   ├── Duration.lua              # Time duration type
│   │   ├── Command.lua               # Command type
│   │   ├── UserInput.lua             # Input types
│   │   ├── BindableResource.lua      # Bindable resource type
│   │   └── ConditionFunction.lua     # Condition function type
│   ├── Commands/
│   │   └── blink.lua                 # Example: Teleport to mouse
│   └── DefaultEventHandlers.lua      # Event handling setup
└── README.md                         # This file
```

## 🎯 How It Works

### The Problem
Roblox executors can't create ModuleScripts at runtime, but Cmdr was designed to load commands/types as modules.

### The Solution
1. **Host on GitHub**: All code lives in `.lua` files on GitHub
2. **Custom Require**: A `loadstring`-based require system loads modules via HTTP
3. **UI Asset**: The GUI is loaded from Roblox asset ID `114417681211747`
4. **Client-Only**: Runs entirely on the client (executor environment)

## 📝 Creating Custom Commands

### Example Command (`src/Commands/example.lua`):
```lua
return {
	Name = "example";
	Aliases = {"ex"};
	Description = "An example command";
	Group = "Custom";
	Args = {
		{
			Type = "string";
			Name = "message";
			Description = "Message to display";
		}
	};
	ClientRun = function(context, message)
		return "You said: " .. message
	end
}
```

### Register Your Command

Add to the `commandFiles` array in `init.lua`:
```lua
local commandFiles = {
	"blink",
	"example"  -- Add your command here
}
```

## 🔧 Creating Custom Types

### Example Type (`src/Types/Custom.lua`):
```lua
return function(registry)
	local customType = {
		Transform = function(text)
			-- Transform user input
			return text:upper()
		end;
		
		Validate = function(value)
			-- Validate the transformed value
			return #value > 0, "Value cannot be empty"
		end;
		
		Autocomplete = function(value)
			-- Return suggestions
			return {"OPTION1", "OPTION2", "OPTION3"}
		end;
		
		Parse = function(value)
			-- Final value to pass to command
			return value
		end;
	}
	
	registry:RegisterType("custom", customType)
end
```

### Register Your Type

Add to the `typeFiles` array in `init.lua`:
```lua
local typeFiles = {
	"Primitives",
	"Player",
	-- ... other types
	"Custom"  -- Add your type here
}
```

## 🎮 Player Type Shorthands

The player type supports special shorthands:
- `.` or `me` - You
- `*` or `all` - All players
- `others` - Everyone except you
- `?` - Random player
- `?5` - 5 random players

## 🛠️ API Reference

### Cmdr Object

```lua
-- Show/hide the interface
Cmdr:Show()
Cmdr:Hide()
Cmdr:Toggle()

-- Execute a command programmatically
Cmdr:Run("blink")

-- Change activation key
Cmdr:SetActivationKeys({Enum.KeyCode.Semicolon})

-- Change place name display
Cmdr:SetPlaceName("My Game")

-- Enable/disable
Cmdr:SetEnabled(true)

-- Register custom hooks
Cmdr.Registry:RegisterHook("BeforeRun", function(context)
	-- Return nil to allow, string to block
	if context.Executor.UserId == 123456 then
		return "You're banned from commands"
	end
end)
```

### Command Context

Available in command functions:

```lua
ClientRun = function(context, ...)
	context.Executor        -- Player who ran the command
	context.Name            -- Command name
	context.RawText         -- Full command text
	context.Arguments       -- Parsed arguments
	context:Reply("text")   -- Send message to executor
	context:GetStore("name") -- Persistent storage
end
```

## 📦 Type System

### Built-in Types

**Primitives:**
- `string`, `strings`
- `number`, `numbers`
- `integer`, `integers`
- `boolean`, `booleans`

**Roblox Types:**
- `player`, `players`
- `playerId`, `playerIds`
- `team`, `teams`
- `brickColor`, `brickColors`
- `color3`, `color3s`
- `hexColor3`, `hexColor3s`
- `vector2`, `vector2s`
- `vector3`, `vector3s`

**Special:**
- `duration` - Time durations (e.g., "5m", "1h30m")
- `command` - Command names
- `userInput` - KeyCodes and InputTypes

### Listable Types

Types ending in `s` accept comma-separated lists:
```
players me,player2,player3
color3s 255,0,0 0,255,0 0,0,255
```

### Prefixed Types

Some types support prefixes:
- `%Team` - Team prefix for team colors/players
- `#123456` - Hex color prefix
- `!brickColor` - BrickColor name prefix

## 🔒 Security Note

**This is for private games only.** Running arbitrary code from GitHub in a public game is a security risk. Only use this in:
- Private/VIP servers
- Testing environments  
- Personal projects

## 🐛 Debugging

Enable detailed logging:
```lua
-- In init.lua, the system prints loading progress
-- Check F9 console for errors
```

Common issues:
1. **"Failed to load from GitHub"** - Check your internet connection or GitHub URL
2. **"Failed to load UI asset"** - Asset ID may be private or invalid
3. **"Module not found"** - Check file path matches exactly (case-sensitive)

## 📚 Examples

### Simple Command
```lua
-- src/Commands/hello.lua
return {
	Name = "hello";
	Description = "Say hello";
	Args = {};
	ClientRun = function(context)
		return "Hello, " .. context.Executor.Name .. "!"
	end
}
```

### Command with Arguments
```lua
-- src/Commands/teleport.lua
return {
	Name = "teleport";
	Aliases = {"tp"};
	Description = "Teleport to a player";
	Args = {
		{
			Type = "player";
			Name = "target";
			Description = "Player to teleport to";
		}
	};
	ClientRun = function(context, targetPlayer)
		local char = context.Executor.Character
		local targetChar = targetPlayer.Character
		
		if char and targetChar then
			char:MoveTo(targetChar.HumanoidRootPart.Position)
			return "Teleported to " .. targetPlayer.Name
		end
		
		return "Teleport failed"
	end
}
```

## 🔄 Updates

To update your system:
1. Pull latest changes from GitHub
2. Re-run the loader script
3. Commands and types will reload automatically

## 📄 License

This is a modified version of the original Cmdr system, adapted for GitHub loading.

Original Cmdr: https://github.com/evaera/Cmdr

## 🤝 Contributing

To add your own commands/types:
1. Fork this repository
2. Add your `.lua` files
3. Update `init.lua` to include them
4. Update your GitHub URL in the loader

## ⚠️ Limitations

- **No server-side execution** - Commands run client-only
- **No RemoteEvents** - Can't communicate with server
- **No DataStores** - No persistent storage between sessions
- **No file system** - Can't read/write local files

For full Cmdr features, use the original version in a proper Roblox game.

## 🎓 Learning Resources

- **Command Structure**: See `src/Commands/blink.lua`
- **Type Structure**: See `src/Types/Primitives.lua`
- **Original Docs**: https://eryn.io/Cmdr/

---

**Made for educational purposes. Use responsibly.**
