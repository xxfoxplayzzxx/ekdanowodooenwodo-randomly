local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- Create the container inside the Player instance (not the Character)
local MainModule = Instance.new("ModuleScript")
MainModule.Name = "Main"
MainModule.Source = [[
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Shared = script:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local Cmdr do
	Cmdr = setmetatable({
		ReplicatedRoot = script;
		RemoteFunction = script:WaitForChild("CmdrFunction");
		RemoteEvent = script:WaitForChild("CmdrEvent");
		ActivationKeys = {[Enum.KeyCode.F2] = true};
		Enabled = true;
		MashToEnable = false;
		ActivationUnlocksMouse = false;
		HideOnLostFocus = true;
		PlaceName = "Cmdr";
		Util = Util;
		Events = {};
	}, {
		-- This sucks, and may be redone or removed
		-- Proxies dispatch methods on to main Cmdr object
		__index = function (self, k)
			local r = self.Dispatcher[k]
			if r and type(r) == "function" then
				return function (_, ...)
					return r(self.Dispatcher, ...)
				end
			end
		end
	})

	Cmdr.Registry = require(Shared.Registry)(Cmdr)
	Cmdr.Dispatcher = require(Shared.Dispatcher)(Cmdr)
end

if script:WaitForChild("Cmdr") and wait() and Player:WaitForChild("PlayerGui"):FindFirstChild("Cmdr") == nil then
	script.Cmdr:Clone().Parent = Player.PlayerGui
end

local Interface = require(script:WaitForChild("CmdrInterface"))(Cmdr)

--- Sets a list of keyboard keys (Enum.KeyCode) that can be used to open the commands menu
function Cmdr:SetActivationKeys (keysArray)
	self.ActivationKeys = Util.MakeDictionary(keysArray)
end

--- Sets the place name label on the interface
function Cmdr:SetPlaceName (name)
	self.PlaceName = name
	Interface.Window:UpdateLabel()
end

--- Sets whether or not the console is enabled
function Cmdr:SetEnabled (enabled)
	self.Enabled = enabled
end

--- Sets if activation will free the mouse.
function Cmdr:SetActivationUnlocksMouse (enabled)
	self.ActivationUnlocksMouse = enabled
end

--- Shows Cmdr window
function Cmdr:Show ()
	if not self.Enabled then
		return
	end

	Interface.Window:Show()
end

--- Hides Cmdr window
function Cmdr:Hide ()
	Interface.Window:Hide()
end

--- Toggles Cmdr window
function Cmdr:Toggle ()
	if not self.Enabled then
		return self:Hide()
	end

	Interface.Window:SetVisible(not Interface.Window:IsVisible())
end

--- Enables the "Mash to open" feature
function Cmdr:SetMashToEnable(isEnabled)
	self.MashToEnable = isEnabled

	if isEnabled then
		self:SetEnabled(false)
	end
end

--- Sets the hide on 'lost focus' feature.
function Cmdr:SetHideOnLostFocus(enabled)
	self.HideOnLostFocus = enabled
end

--- Sets the handler for a certain event type
function Cmdr:HandleEvent(name, callback)
	self.Events[name] = callback
end

-- Only register when we aren't in studio because don't want to overwrite what the server portion did
if RunService:IsServer() == false then
	Cmdr.Registry:RegisterTypesIn(script:WaitForChild("Types"))
	Cmdr.Registry:RegisterCommandsIn(script:WaitForChild("Commands"))
end

-- Hook up event listener
Cmdr.RemoteEvent.OnClientEvent:Connect(function(name, ...)
	if Cmdr.Events[name] then
		Cmdr.Events[name](...)
	end
end)

require(script.DefaultEventHandlers)(Cmdr)

return Cmdr

]]

-- Debug: Parent it to LocalPlayer (Invisible to standard server-side checks)
MainModule.Parent = LP 

-- Asset Loading (Childing them to Main)
local assetIds = {99412149592640, 118279463989367, 114417681211747}

for _, id in ipairs(assetIds) do
    local success, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)
    end)
    
    if success and objects and objects[1] then
        local asset = objects[1]
        
        -- Check if the asset is a "Group" (Model or Folder)
        if asset:IsA("Model") and asset.Name == "Model" then
            
            -- Move all children to MainModule
            for _, child in ipairs(asset:GetChildren()) do
                child.Parent = MainModule
            end
            
            -- Remove the empty container
            asset:Destroy()
        else
            -- If it's a single object (like a ModuleScript), just parent it
            asset.Parent = MainModule
            print("Loaded Single Asset: " .. asset.Name)
        end
    else
        warn("Failed to load asset ID: " .. tostring(id))
    end
end

-- Setup Commands Folder
local CommandsFolder = Instance.new("Folder")
CommandsFolder.Name = "Commands"
CommandsFolder.Parent = MainModule

local function BuildCommand(name, sourceCode)
    local cmdModule = Instance.new("ModuleScript")
    cmdModule.Name = name
    cmdModule.Source = sourceCode
    cmdModule.Parent = CommandsFolder
end

-- Your Thru Logic
BuildCommand("thru", [[
    return {
        Name = "thru",
        Aliases = {"t"},
        Description = "Move forward.",
        Group = "DefaultDebug",
        Args = {{Type = "number", Name = "Distance", Default = 2}},
        Run = function(context, dist)
            local root = context.Executor.Character.HumanoidRootPart
            root.CFrame = root.CFrame + (root.CFrame.LookVector * dist)
            return "Teleported"
        end
    }
]])

-- FINAL REQUIRE WITH DEBUG LOGS
print("Attempting to require Main from LocalPlayer...")
local success, result = pcall(function()
    return require(MainModule)
end)

if success then
    print("Main Module successfully loaded into memory.")
else
    warn("Failed to load Main: " .. tostring(result))
end
