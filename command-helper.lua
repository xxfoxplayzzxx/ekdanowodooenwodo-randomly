local Players = game:GetService("Players")

local MainModule = Instance.new("ModuleScript")
MainModule.Name = "Main"
MainModule.Source = [[local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Shared = script:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

if RunService:IsClient() == false then
	error("Server scripts cannot require the client library. Please require the server library to use Cmdr in your own code.")
end

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
MainModule.Parent = nil

local assetIds = {99412149592640, 118279463989367, 114417681211747}

for _, id in ipairs(assetIds) do
    local success, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)
    end)
    
    if success and objects and objects[1] then
        local asset = objects[1]
        asset.Parent = MainModule
    end
end

local CommandsFolder = Instance.new("Folder")
CommandsFolder.Name = "Commands"
CommandsFolder.Parent = MainModule

local function BuildCommand(name, sourceCode)
    local cmdModule = Instance.new("ModuleScript")
    cmdModule.Name = name
    cmdModule.Source = sourceCode
    
    cmdModule.Parent = CommandsFolder
    return cmdModule
end

local CommandData = {
    {
        FileName = "thru",
        Source = [[
            return {
                Name = "thru",
                Aliases = {"t", "through"},
                Description = "Teleports you forward.",
                Group = "DefaultDebug",
                Args = {{Type = "number", Name = "Distance", Default = 0}},

                Run = function(context, distanceArg)
                    local player = context.Executor
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if not root then return "No root part found." end
                    
                    local dist = (distanceArg ~= 0) and distanceArg or 2
                    root.CFrame = root.CFrame + (root.CFrame.LookVector * dist)
                    
                    root.Velocity = Vector3.new(0, 0, 0)
                    root.RotVelocity = Vector3.new(0, 0, 0)
                    root.Anchored = true
                    task.delay(0.1, function() if root then root.Anchored = false end end)
                    
                    return "Gone thru"
                end
            }
        ]]
    },
    {
        FileName = "invisible",
        Source = [[
            return {
                Name = "invisible",
                Aliases = {"snail"},
                Description = "The snail-lock logic.",
                Group = "DefaultUtil",
                Args = {},
                Run = function(context)
                    return "Snail mode logic initialized."
                end
            }
        ]]
    }
}

for _, data in ipairs(CommandData) do
    pcall(function()
        BuildCommand(data.FileName, data.Source)
    end)
end

require(MainModule)
