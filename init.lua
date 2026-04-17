-- Cmdr Executor Loader
-- Load this file first from your executor
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/cmdr-executor/main/init.lua"))()

local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/YOUR_USERNAME/cmdr-executor/main/"
local UI_ASSET_ID = 114417681211747

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Custom require system for loading from GitHub
local LoadedModules = {}
local ModuleCache = {}

local function httpGet(url)
	local success, result = pcall(function()
		return game:HttpGet(url, true)
	end)
	if not success then
		error("Failed to load from GitHub: " .. url .. "\nError: " .. tostring(result))
	end
	return result
end

local function customRequire(modulePath)
	-- Handle relative paths
	if modulePath:sub(1, 1) == "." then
		error("Relative paths not supported in executor mode")
	end
	
	-- Check cache first
	if ModuleCache[modulePath] then
		return ModuleCache[modulePath]
	end
	
	-- Load from GitHub
	local url = GITHUB_RAW_BASE .. modulePath .. ".lua"
	local source = httpGet(url)
	
	-- Create module environment
	local moduleFunc, loadError = loadstring(source, modulePath)
	if not moduleFunc then
		error("Failed to load module " .. modulePath .. ": " .. tostring(loadError))
	end
	
	-- Set up environment
	local env = setmetatable({}, {__index = getfenv()})
	env.script = {
		Parent = {
			Parent = {
				Shared = {
					WaitForChild = function(self, name)
						return {
							Name = name
						}
					end
				}
			}
		},
		WaitForChild = function(self, name)
			return {
				Name = name,
				GetChildren = function() return {} end
			}
		end
	}
	setfenv(moduleFunc, env)
	
	-- Execute module
	local result = moduleFunc()
	
	-- Cache the result
	ModuleCache[modulePath] = result
	
	return result
end

-- Make require available globally
getfenv().require = customRequire

print("[Cmdr Executor] Loading Cmdr from GitHub...")

-- Load the UI first
local CmdrUI
local success, err = pcall(function()
	CmdrUI = game:GetObjects("rbxassetid://" .. UI_ASSET_ID)[1]
end)

if not success or not CmdrUI then
	error("[Cmdr Executor] Failed to load UI asset: " .. tostring(err))
end

-- Load core modules
print("[Cmdr Executor] Loading Util...")
local Util = customRequire("src/Shared/Util")

print("[Cmdr Executor] Loading Registry...")
local Registry = customRequire("src/Shared/Registry")

print("[Cmdr Executor] Loading Dispatcher...")
local Dispatcher = customRequire("src/Shared/Dispatcher")

print("[Cmdr Executor] Loading Command...")
local Command = customRequire("src/Shared/Command")

print("[Cmdr Executor] Loading Argument...")
local Argument = customRequire("src/Shared/Argument")

-- Create the Cmdr object
local Cmdr = setmetatable({
	ReplicatedRoot = {
		Types = {
			GetChildren = function() return {} end
		},
		Commands = {
			GetChildren = function() return {} end
		}
	},
	RemoteFunction = {
		InvokeServer = function() return "Server functions not available in executor mode" end
	},
	RemoteEvent = {
		OnClientEvent = {
			Connect = function() end
		},
		FireClient = function() end,
		FireAllClients = function() end
	},
	ActivationKeys = {[Enum.KeyCode.F2] = true},
	Enabled = true,
	MashToEnable = false,
	ActivationUnlocksMouse = false,
	HideOnLostFocus = true,
	PlaceName = "Cmdr (Executor)",
	Util = Util,
	Events = {},
	DefaultCommandsFolder = {
		GetChildren = function() return {} end,
		FindFirstChild = function() return nil end
	}
}, {
	__index = function(self, k)
		local r = self.Dispatcher and self.Dispatcher[k]
		if r and type(r) == "function" then
			return function(_, ...)
				return r(self.Dispatcher, ...)
			end
		end
	end
})

-- Initialize Registry and Dispatcher
Cmdr.Registry = Registry(Cmdr)
Cmdr.Dispatcher = Dispatcher(Cmdr)

-- Clone UI to PlayerGui
if CmdrUI and Player:WaitForChild("PlayerGui"):FindFirstChild("Cmdr") == nil then
	CmdrUI.Parent = Player.PlayerGui
	Cmdr.UI = CmdrUI
end

-- Load interface
print("[Cmdr Executor] Loading Interface...")
local Interface = customRequire("src/CmdrInterface/init")(Cmdr)

-- Cmdr API functions
function Cmdr:SetActivationKeys(keysArray)
	self.ActivationKeys = Util.MakeDictionary(keysArray)
end

function Cmdr:SetPlaceName(name)
	self.PlaceName = name
	Interface.Window:UpdateLabel()
end

function Cmdr:SetEnabled(enabled)
	self.Enabled = enabled
end

function Cmdr:SetActivationUnlocksMouse(enabled)
	self.ActivationUnlocksMouse = enabled
end

function Cmdr:Show()
	if not self.Enabled then
		return
	end
	Interface.Window:Show()
end

function Cmdr:Hide()
	Interface.Window:Hide()
end

function Cmdr:Toggle()
	if not self.Enabled then
		return self:Hide()
	end
	Interface.Window:SetVisible(not Interface.Window:IsVisible())
end

function Cmdr:SetMashToEnable(isEnabled)
	self.MashToEnable = isEnabled
	if isEnabled then
		self:SetEnabled(false)
	end
end

function Cmdr:SetHideOnLostFocus(enabled)
	self.HideOnLostFocus = enabled
end

function Cmdr:HandleEvent(name, callback)
	self.Events[name] = callback
end

-- Register default types
print("[Cmdr Executor] Registering types...")
local typeFiles = {
	"Primitives",
	"Player",
	"PlayerId",
	"Team",
	"BrickColor",
	"Color3",
	"Vector",
	"Duration",
	"Command",
	"BindableResource",
	"ConditionFunction",
	"UserInput"
}

for _, typeName in ipairs(typeFiles) do
	local success, err = pcall(function()
		local typeModule = customRequire("src/Types/" .. typeName)
		typeModule(Cmdr.Registry)
	end)
	if not success then
		warn("[Cmdr Executor] Failed to load type " .. typeName .. ": " .. tostring(err))
	end
end

-- Register default commands
print("[Cmdr Executor] Registering commands...")
local commandFiles = {
	"blink"
}

for _, cmdName in ipairs(commandFiles) do
	local success, err = pcall(function()
		local cmdModule = customRequire("src/Commands/" .. cmdName)
		Cmdr.Registry:RegisterCommandObject(cmdModule, true)
	end)
	if not success then
		warn("[Cmdr Executor] Failed to load command " .. cmdName .. ": " .. tostring(err))
	end
end

-- Set up event handlers
customRequire("src/DefaultEventHandlers")(Cmdr)

-- Expose globally
getfenv().Cmdr = Cmdr

print("[Cmdr Executor] Loaded successfully! Press F2 to open.")
print("[Cmdr Executor] Access via global 'Cmdr' variable")

return Cmdr
