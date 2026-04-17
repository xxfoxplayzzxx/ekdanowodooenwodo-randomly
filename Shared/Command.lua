local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IsServer = RunService:IsServer()

local Command = {}
Command.__index = Command

function Command.new (options)
	local self = {
		Dispatcher = options.Dispatcher;
		Cmdr = options.Dispatcher.Cmdr;
		Name = options.CommandObject.Name;
		RawText = options.Text;
		Object = options.CommandObject;
		Group = options.CommandObject.Group;
		State = {};
		Aliases = options.CommandObject.Aliases;
		Alias = options.Alias;
		Description = options.CommandObject.Description;
		Executor = options.Executor;
		ArgumentDefinitions = options.CommandObject.Args;
		RawArguments = options.Arguments;
		Arguments = {};
		Data = options.Data;
		Response = nil;
	}

	setmetatable(self, Command)
	return self
end

function Command:Parse (allowIncompleteArguments)
	local Argument = require("src/Shared/Argument")
	local hadOptional = false

	for i, definition in ipairs(self.ArgumentDefinitions) do
		if type(definition) == "function" then
			definition = definition(self)
			if definition == nil then
				break
			end
		end

		local required = (definition.Default == nil and definition.Optional ~= true)

		if required and hadOptional then
			error(("Command %q: Required arguments cannot occur after optional arguments."):format(self.Name))
		elseif not required then
			hadOptional = true
		end

		if self.RawArguments[i] == nil and required and allowIncompleteArguments ~= true then
			return false, ("Required argument #%d %s is missing."):format(i, definition.Name)
		elseif self.RawArguments[i] or allowIncompleteArguments then
			self.Arguments[i] = Argument.new(self, definition, self.RawArguments[i] or "")
		end
	end

	return true
end

function Command:Validate (isFinal)
	self._Validated = true
	local errorText = ""
	local success = true

	for i, arg in pairs(self.Arguments) do
		local argSuccess, argErrorText = arg:Validate(isFinal)

		if not argSuccess then
			success = false
			errorText = ("%s; #%d %s: %s"):format(errorText, i, arg.Name, argErrorText or "error")
		end
	end

	return success, errorText:sub(3)
end

function Command:Run ()
	if self._Validated == nil then
		error("Must validate a command before running.")
	end

	if not IsServer and self.Object.Data and self.Data == nil then
		local values, length = self:GatherArgumentValues()
		self.Data = self.Object.Data(self, unpack(values, 1, length))
	end

	if not IsServer and self.Object.ClientRun then
		local values, length = self:GatherArgumentValues()
		self.Response = self.Object.ClientRun(self, unpack(values, 1, length))
	end

	if self.Response == nil then
		if self.Object.Run then
			local values, length = self:GatherArgumentValues()
			self.Response = self.Object.Run(self, unpack(values, 1, length))
		elseif IsServer then
			if self.Object.ClientRun then
				warn(self.Name, "command fell back to the server but there is no server implementation!")
			else
				warn(self.Name, "command has no implementation!")
			end
			self.Response = "No implementation."
		else
			self.Response = self.Dispatcher:Send(self.RawText, self.Data)
		end
	end

	local afterRunHook = self.Dispatcher:RunHooks("AfterRun", self)

	if afterRunHook then
		return afterRunHook
	else
		return self.Response
	end
end

function Command:GatherArgumentValues()
	local values = {}

	for i, arg in pairs(self.Arguments) do
		values[i] = arg:GetValue()
	end

	return values, #self.Arguments
end

function Command:GetArgument (index)
	return self.Arguments[index]
end

function Command:GetData ()
	if self.Data then
		return self.Data
	end

	if self.Object.Data and not IsServer then
		self.Data = self.Object.Data(self)
	end

	return self.Data
end

function Command:SendEvent(player, event, ...)
	assert(typeof(player) == "Instance", "Argument #1 must be a Player")
	assert(player:IsA("Player"), "Argument #1 must be a Player")
	assert(type(event) == "string", "Argument #2 must be a string")

	if IsServer then
		self.Dispatcher.Cmdr.RemoteEvent:FireClient(player, event, ...)
	elseif self.Dispatcher.Cmdr.Events[event] then
		assert(player == Players.LocalPlayer, "Event messages can only be sent to the local player on the client.")
		self.Dispatcher.Cmdr.Events[event](...)
	end
end

function Command:BroadcastEvent(...)
	if not IsServer then
		error("Can't broadcast event messages from the client.", 2)
	end

	self.Dispatcher.Cmdr.RemoteEvent:FireAllClients(...)
end

function Command:Reply(...)
	return self:SendEvent(self.Executor, "AddLine", ...)
end

function Command:GetStore(...)
	return self.Dispatcher.Cmdr.Registry:GetStore(...)
end

function Command:HasImplementation()
	return ((RunService:IsClient() and self.Object.ClientRun) or self.Object.Run) and true or false
end

return Command
