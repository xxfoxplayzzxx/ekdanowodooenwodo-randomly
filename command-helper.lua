local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- Create the container inside the Player instance (not the Character)
local MainModule = Instance.new("ModuleScript")
MainModule.Name = "Main"
MainModule.Source = [[
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- Debugging: Wait for children to exist before running
local Shared = script:WaitForChild("Shared", 5)
if not Shared then error("CRITICAL: Shared folder not found in Main!") end

local Util = require(Shared:WaitForChild("Util"))

local Cmdr do
    Cmdr = setmetatable({
        ReplicatedRoot = script;
        RemoteFunction = script:WaitForChild("CmdrFunction");
        RemoteEvent = script:WaitForChild("CmdrEvent");
        ActivationKeys = {[Enum.KeyCode.F2] = true};
        Enabled = true;
        PlaceName = "Cmdr";
        Util = Util;
        Events = {};
    }, {
        __index = function (self, k)
            local r = self.Dispatcher[k]
            if r and type(r) == "function" then
                return function (_, ...) return r(self.Dispatcher, ...) end
            end
        end
    })

    Cmdr.Registry = require(Shared.Registry)(Cmdr)
    Cmdr.Dispatcher = require(Shared.Dispatcher)(Cmdr)
end

local Interface = require(script:WaitForChild("CmdrInterface"))(Cmdr)

if RunService:IsServer() == false then
    Cmdr.Registry:RegisterTypesIn(script:WaitForChild("Types"))
    Cmdr.Registry:RegisterCommandsIn(script:WaitForChild("Commands"))
end

require(script:WaitForChild("DefaultEventHandlers"))(Cmdr)

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
            print("Ungrouping asset: " .. asset.Name)
            
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
