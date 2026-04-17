local Argument = {}
Argument.__index = Argument

function Argument.new (command, argumentObject, value)
	local Util = command.Cmdr.Util
	
	local self = {
		Command = command;
		Type = nil;
		Name = argumentObject.Name;
		Object = argumentObject;
		Required = argumentObject.Default == nil and argumentObject.Optional ~= true;
		Executor = command.Executor;
		RawValue = value;
		RawSegments = {};
		TransformedValues = {};
		Prefix = "";
	}

	if type(argumentObject.Type) == "table" then
		self.Type = argumentObject.Type
	else
		local parsedType, parsedRawValue, prefix = Util.ParsePrefixedUnionType(
			command.Cmdr.Registry:GetTypeName(argumentObject.Type),
			value
		)

		self.Type = command.Dispatcher.Registry:GetType(parsedType)
		self.RawValue = parsedRawValue
		self.Prefix = prefix

		if self.Type == nil then
			error(string.format("%s has an unregistered type %q", self.Name or "<none>", parsedType or "<none>"))
		end
	end

	setmetatable(self, Argument)
	self:Transform()

	return self
end

function Argument:Transform()
	if #self.TransformedValues ~= 0 then
		return
	end

	local Util = self.Command.Cmdr.Util

	if self.Type.Listable and #self.RawValue > 0 then
		local rawSegments = Util.SplitStringSimple(self.RawValue, ",")

		if self.RawValue:sub(#self.RawValue, #self.RawValue) == "," then
			rawSegments[#rawSegments + 1] = ""
		end

		for i, rawSegment in ipairs(rawSegments) do
			self.RawSegments[i] = rawSegment
			self.TransformedValues[i] = { self:TransformSegment(rawSegment) }
		end
	else
		self.RawSegments[1] = self.RawValue
		self.TransformedValues[1] = { self:TransformSegment(self.RawValue) }
	end
end

function Argument:TransformSegment(rawSegment)
	if self.Type.Transform then
		return self.Type.Transform(rawSegment, self.Executor)
	else
		return rawSegment
	end
end

function Argument:GetTransformedValue(segment)
	return unpack(self.TransformedValues[segment])
end

function Argument:Validate(isFinal)
	if self.RawValue == nil or #self.RawValue == 0 and self.Required == false then
		return true
	end

	if self.Type.Validate or self.Type.ValidateOnce then
		for i = 1, #self.TransformedValues do
			if self.Type.Validate then
				local valid, errorText = self.Type.Validate(self:GetTransformedValue(i))

				if not valid then
					return valid, errorText or "Invalid value"
				end
			end

			if isFinal and self.Type.ValidateOnce then
				local validOnce, errorTextOnce = self.Type.ValidateOnce(self:GetTransformedValue(i))

				if not validOnce then
					return validOnce, errorTextOnce
				end
			end
		end

		return true
	else
		return true
	end
end

function Argument:GetAutocomplete()
	if self.Type.Autocomplete then
		return self.Type.Autocomplete(self:GetTransformedValue(#self.TransformedValues))
	else
		return {}
	end
end

function Argument:ParseValue(i)
	if self.Type.Parse then
		return self.Type.Parse(self:GetTransformedValue(i))
	else
		return self:GetTransformedValue(i)
	end
end

function Argument:GetValue()
	if #self.RawValue == 0 and not self.Required and self.Object.Default ~= nil then
		return self.Object.Default
	end

	if not self.Type.Listable then
		return self:ParseValue(1)
	end

	local values = {}

	for i = 1, #self.TransformedValues do
		local parsedValue = self:ParseValue(i)

		if type(parsedValue) ~= "table" then
			error(("Listable types must return a table from Parse (%s)"):format(self.Type.Name))
		end

		for _, value in pairs(parsedValue) do
			values[value] = true
		end
	end

	local valueArray = {}

	for value in pairs(values) do
		valueArray[#valueArray + 1] = value
	end

	return valueArray
end

return Argument
