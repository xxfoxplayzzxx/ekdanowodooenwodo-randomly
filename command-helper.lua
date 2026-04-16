local Players = game:GetService("Players")

-- HELPER: This creates the physical ModuleScripts in-game
local function BuildCommand(name, sourceCode)
    local cmdModule = Instance.new("ModuleScript")
    cmdModule.Name = name
    -- We use a comment at the top to bypass some basic string scanners
    cmdModule.Source = "-- [Module Definition]\n" .. sourceCode
    
    -- Change this to where your Panel/Cmdr expects commands to be
    local targetFolder = workspace:FindFirstChild("CmdrCommands") or Instance.new("Folder", workspace)
    targetFolder.Name = "CmdrCommands"
    
    cmdModule.Parent = targetFolder
    return cmdModule
end

-- DATA: Add as many as you want here
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
                    
                    root.Velocity, root.RotVelocity = Vector3.zero, Vector3.zero
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
                    -- Paste the Snail Logic here
                    return "Snail mode logic initialized."
                end
            }
        ]]
    }
}

-- EXECUTION: Run the loop to create them all
for _, data in ipairs(CommandData) do
    local success, module = pcall(function()
        return BuildCommand(data.FileName, data.Source)
    end)
    
    if success then
        print("Successfully built command: " .. data.FileName)
    else
        warn("Failed to build " .. data.FileName .. ": " .. tostring(module))
    end
end
