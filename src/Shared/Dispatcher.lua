local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

return function(cmdr)
	local Util = cmdr.Util
	local Command = require("src/Shared/Command")
	
	local HISTORY_SETTING_NAME = "CmdrCommandHistory"
	local displayedBeforeRunHookWarning = false
	
	local Dispatcher = {
		Cmdr = cmdr;
		Registry = cmdr.Registry;
	}

	function Dispatcher:Evaluate (text, executor, allowIncompleteArguments, data)
		if RunService:IsClient() == true and executor ~= Players.LocalPlayer then
			error("Can't evaluate a command that isn't sent by the local player.")
		end

		local arguments = Util.SplitString(text)
		local commandName = table.remove(arguments, 1)
		local commandObject = self.Registry:GetCommand(commandName)

		if commandObject then
			arguments = Util.MashExcessArguments(arguments, #commandObject.Args)

			local command = Command.new({
				Dispatcher = self,
				Text = text,
				CommandObject = commandObject,
				Alias = commandName,
				Executor = executor,
				Arguments = arguments,
				Data = data
			})

			local success, errorText = command:Parse(allowIncompleteArguments)

			if success then
				return command
			else
				return false, errorText
			end
		else
			return false, ("%q is not a valid command name. Use the help command to see all available commands."):format(tostring(commandName))
		end
	end

	function Dispatcher:EvaluateAndRun (text, executor, options)
		executor = executor or Players.LocalPlayer
		options = options or {}

		if RunService:IsClient() and options.IsHuman then
			self:PushHistory(text)
		end

		local command, errorText = self:Evaluate(text, executor, nil, options.Data)

		if not command then
			return errorText
		end

		local ok, out = xpcall(function()
			local valid, errorText = command:Validate(true)

			if not valid then
				return errorText
			end

			return command:Run() or "Command executed."
		end, function(value)
			return debug.traceback(tostring(value))
		end)

		if not ok then
			warn(("Error occurred while evaluating command string %q\n%s"):format(text, tostring(out)))
		end

		return ok and out or "An error occurred while running this command."
	end

	function Dispatcher:Send (text, data)
		if RunService:IsClient() == false then
			error("Dispatcher:Send can only be called from the client.")
		end

		return self.Cmdr.RemoteFunction:InvokeServer(text, {
			Data = data
		})
	end

	function Dispatcher:Run (...)
		if not Players.LocalPlayer then
			error("Dispatcher:Run can only be called from the client.")
		end

		local args = {...}
		local text = args[1]

		for i = 2, #args do
			text = text .. " " .. tostring(args[i])
		end

		local command, errorText = self:Evaluate(text, Players.LocalPlayer)

		if not command then
			error(errorText)
		end

		local success, errorText = command:Validate(true)

		if not success then
			error(errorText)
		end

		return command:Run()
	end

	function Dispatcher:RunHooks(hookName, commandContext, ...)
		if not self.Registry.Hooks[hookName] then
			error(("Invalid hook name: %q"):format(hookName), 2)
		end

		if
			hookName == "BeforeRun"
			and #self.Registry.Hooks[hookName] == 0
			and commandContext.Group ~= "DefaultUtil"
			and commandContext.Group ~= "UserAlias"
			and commandContext:HasImplementation()
		then
			if RunService:IsStudio() then
				if displayedBeforeRunHookWarning == false then
					commandContext:Reply((RunService:IsServer() and "<Server>" or "<Client>") .. " Commands will not run in-game if no BeforeRun hook is configured.")
					displayedBeforeRunHookWarning = true
				end
			else
				return "Command blocked for security as no BeforeRun hook is configured."
			end
		end

		for _, hook in ipairs(self.Registry.Hooks[hookName]) do
			local value = hook.callback(commandContext, ...)

			if value ~= nil then
				return tostring(value)
			end
		end
	end

	function Dispatcher:PushHistory(text)
		assert(RunService:IsClient(), "PushHistory may only be used from the client.")

		local history = self:GetHistory()

		if Util.TrimString(text) == "" or text == history[#history] then
			return
		end

		history[#history + 1] = text
		TeleportService:SetTeleportSetting(HISTORY_SETTING_NAME, history)
	end

	function Dispatcher:GetHistory()
		assert(RunService:IsClient(), "GetHistory may only be used from the client.")
		return TeleportService:GetTeleportSetting(HISTORY_SETTING_NAME) or {}
	end

	return Dispatcher
end
