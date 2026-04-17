local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- 1. Create the physical container
local Container = Instance.new("Folder")
Container.Name = "Cmdr_Final_Fix"
Container.Parent = LP

-- 2. Virtual Loader (Bypasses the 'require' hang)
local function vRequire(obj)
    local fn, err = loadstring(obj.Source)
    if not fn then error("Loadstring error in " .. obj.Name .. ": " .. err) end
    return fn()
end

-- 3. Asset Loading & Flattening
local assetIds = {99412149592640, 118279463989367, 114417681211747}
for _, id in ipairs(assetIds) do
    pcall(function()
        local objects = game:GetObjects("rbxassetid://" .. id)
        for _, asset in ipairs(objects) do
            if asset:IsA("Model") then
                for _, child in ipairs(asset:GetChildren()) do
                    child.Parent = Container
                end
                asset:Destroy()
            else
                asset.Parent = Container
            end
        end
    end)
end

-- 4. Create Commands Folder
local CommandsFolder = Container:FindFirstChild("Commands") or Instance.new("Folder", Container)
CommandsFolder.Name = "Commands"

-- 5. The Main Logic String
-- We use '...' to catch the Container passed from the bootstrapper
local mainSource = [[
    local Root = ... 
    local RunService = game:GetService("RunService")
    local Player = game:GetService("Players").LocalPlayer
    
    -- Inline Virtual Require Helper
    local function vReq(obj)
        return loadstring(obj.Source)()
    end

    local Shared = Root:WaitForChild("Shared")
    local Util = vReq(Shared:WaitForChild("Util"))

    local Cmdr do
        Cmdr = setmetatable({
            ReplicatedRoot = Root;
            RemoteFunction = Root:WaitForChild("CmdrFunction");
            RemoteEvent = Root:WaitForChild("CmdrEvent");
            ActivationKeys = {[Enum.KeyCode.F2] = true};
            Enabled = true;
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

        Cmdr.Registry = vReq(Shared:WaitForChild("Registry"))(Cmdr)
        Cmdr.Dispatcher = vReq(Shared:WaitForChild("Dispatcher"))(Cmdr)
    end

    local Interface = vReq(Root:WaitForChild("CmdrInterface"))(Cmdr)

    if RunService:IsServer() == false then
        Cmdr.Registry:RegisterTypesIn(Root:WaitForChild("Types"))
        Cmdr.Registry:RegisterCommandsIn(Root:WaitForChild("Commands"))
    end

    vReq(Root:WaitForChild("DefaultEventHandlers"))(Cmdr)
    
    print("Cmdr System fully initialized via Root Injection.")
    return Cmdr
]]

-- 6. Execution (The "Container Injection" method)
local fn, err = loadstring(mainSource)
if fn then
    -- We pass Container here so the code sees it as '...'
    task.spawn(fn, Container) 
else
    warn("Failed to compile Main logic: " .. tostring(err))
end
