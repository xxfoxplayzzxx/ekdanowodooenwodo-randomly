local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- 1. Container
local Container = Instance.new("Folder")
Container.Name = "Cmdr_Final_Fix"
Container.Parent = LP

-- 2. Asset Loading & Flattening
local assetIds = {99412149592640, 118279463989367, 114417681211747, 83827561589516}
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

-- 3. Module loader
local function loadModule(instance, ...)
    if not instance then
        warn("loadModule: nil instance") return nil
    end
    local source = instance.Source
    if not source or source == "" then
        source = (decompile and decompile(instance)) or nil
    end
    if not source then
        warn("loadModule: no source on " .. instance.Name) return nil
    end
    local fn, err = loadstring(source)
    if not fn then
        warn("loadModule compile error [" .. instance.Name .. "]: " .. tostring(err)) return nil
    end
    return fn(...)
end

-- 4. Main execution
task.spawn(function()
    local Root = Container

    local Shared    = Root:WaitForChild("Shared")
    local Types     = Root:WaitForChild("Types")
    local Commands  = Root:WaitForChild("Commands")

    -- Load Util first, everything depends on it
    local Util = loadModule(Shared:WaitForChild("Util"))

    -- Build Cmdr object
    local Cmdr
    Cmdr = setmetatable({
        ReplicatedRoot  = Root;
        RemoteFunction  = Root:WaitForChild("CmdrFunction");
        RemoteEvent     = Root:WaitForChild("CmdrEvent");
        ActivationKeys  = {[Enum.KeyCode.F2] = true};
        Enabled         = true;
        Util            = Util;
        Events          = {};
    }, {
        __index = function(self, k)
            local r = self.Dispatcher and self.Dispatcher[k]
            if r and type(r) == "function" then
                return function(_, ...) return r(self.Dispatcher, ...) end
            end
        end
    })

    -- Load Registry and Dispatcher from Shared
    Cmdr.Registry   = loadModule(Shared:WaitForChild("Registry"),   Cmdr)
    Cmdr.Dispatcher = loadModule(Shared:WaitForChild("Dispatcher"), Cmdr)

    -- Load CmdrInterface (ModuleScript, child of CmdrClient in the tree)
    -- It lives as a direct child of CmdrClient, so find it properly
    local CmdrClient    = Root:WaitForChild("CmdrClient")
    local CmdrInterface = CmdrClient:WaitForChild("CmdrInterface")
    loadModule(CmdrInterface, Cmdr)

    -- Move the ScreenGui into PlayerGui so it actually renders
    local Gui = Root:FindFirstChild("Cmdr") -- the ScreenGui
    if Gui then
        local clone = Gui:Clone()
        clone.Parent = LP:WaitForChild("PlayerGui")
    end

    -- Register Types
    for _, module in ipairs(Types:GetChildren()) do
        if module:IsA("ModuleScript") then
            local ok, err = pcall(function()
                local typeData = loadModule(module)
                if typeData then
                    Cmdr.Registry:RegisterType(module.Name, typeData)
                end
            end)
            if not ok then warn("Type registration failed [" .. module.Name .. "]: " .. tostring(err)) end
        end
    end

    -- Register Commands
    for _, module in ipairs(Commands:GetChildren()) do
        if module:IsA("ModuleScript") then
            local ok, err = pcall(function()
                local cmdData = loadModule(module)
                if cmdData then
                    Cmdr.Registry:RegisterCommand(cmdData)
                end
            end)
            if not ok then warn("Command registration failed [" .. module.Name .. "]: " .. tostring(err)) end
        end
    end

    -- DefaultEventHandlers
    local DEH = Root:FindFirstChild("DefaultEventHandlers")
    if DEH then
        loadModule(DEH, Cmdr)
    else
        warn("DefaultEventHandlers not found, skipping.")
    end

    print("Cmdr fully initialized.")
end)
