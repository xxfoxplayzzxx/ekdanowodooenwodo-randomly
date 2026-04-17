local TextService = game:GetService("TextService")

local Util = {}

--- Takes an array and flips its values into dictionary keys with value of true.
function Util.MakeDictionary(array)
	local dictionary = {}

	for i = 1, #array do
		dictionary[array[i]] = true
	end

	return dictionary
end

-- Takes an array of instances and returns (array<names>, array<instances>)
local function transformInstanceSet(instances)
	local names = {}

	for i = 1, #instances do
		names[i] = instances[i].Name
	end

	return names, instances
end

--- Returns a function that is a fuzzy finder for the specified set or container.
function Util.MakeFuzzyFinder(setOrContainer)
	local names
	local instances = {}

	if typeof(setOrContainer) == "Enum" then
		setOrContainer = setOrContainer:GetEnumItems()
	end

	if typeof(setOrContainer) == "Instance" then
		names, instances = transformInstanceSet(setOrContainer:GetChildren())
	elseif typeof(setOrContainer) == "table" then
		if
			typeof(setOrContainer[1]) == "Instance" or typeof(setOrContainer[1]) == "EnumItem" or
				(typeof(setOrContainer[1]) == "table" and typeof(setOrContainer[1].Name) == "string")
		 then
			names, instances = transformInstanceSet(setOrContainer)
		elseif type(setOrContainer[1]) == "string" then
			names = setOrContainer
		elseif setOrContainer[1] ~= nil then
			error("MakeFuzzyFinder only accepts tables of instances or strings.")
		else
			names = {}
		end
	else
		error("MakeFuzzyFinder only accepts a table, Enum, or Instance.")
	end

	return function(text, returnFirst)
		local results = {}

		for i, name in pairs(names) do
			local value = instances and instances[i] or name

			if name:lower() == text:lower() then
				if returnFirst then
					return value
				else
					table.insert(results, 1, value)
				end
			elseif name:lower():sub(1, #text) == text:lower() then
				results[#results + 1] = value
			end
		end

		if returnFirst then
			return results[1]
		end

		return results
	end
end

--- Takes an array of instances and returns an array of those instances' names.
function Util.GetNames(instances)
	local names = {}

	for i = 1, #instances do
		names[i] = instances[i].Name or tostring(instances[i])
	end

	return names
end

--- Splits a string using a simple separator (no quote parsing)
function Util.SplitStringSimple(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	local i = 1
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end

local function charCode(n)
	return utf8.char(tonumber(n, 16))
end

local function first(x)
	return x
end

--- Parses escape sequences into their fully qualified characters
function Util.ParseEscapeSequences(text)
	return text:gsub("\\(.)", {
		t = "\t";
		n = "\n";
	})
	:gsub("\\u(%x%x%x%x)", charCode)
	:gsub("\\x(%x%x)", charCode)
end

local function encodeControlChars(text)
	return first(
		text
		:gsub("\\\\", string.char(17))
		:gsub("\\\"", string.char(18))
		:gsub("\\'", string.char(19))
	)
end

local function decodeControlChars(text)
	return first(
		text
		:gsub(string.char(17), "\\")
		:gsub(string.char(18), "\"")
		:gsub(string.char(19), "'")
	)
end

--- Splits a string by space but taking into account quoted sequences
function Util.SplitString(text, max)
	text = encodeControlChars(text)
	max = max or math.huge
	local t = {}
	local spat, epat = [=[^(['"])]=], [=[(['"])$]=]
	local buf, quoted
	for str in text:gmatch("%S+") do
		str = Util.ParseEscapeSequences(str)
		local squoted = str:match(spat)
		local equoted = str:match(epat)
		local escaped = str:match([=[(\*)['"]$]=])
		if squoted and not quoted and not equoted then
			buf, quoted = str, squoted
		elseif buf and equoted == quoted and #escaped % 2 == 0 then
			str, buf, quoted = buf .. " " .. str, nil, nil
		elseif buf then
			buf = buf .. " " .. str
		end
		if not buf then
			t[#t + (#t > max and 0 or 1)] = decodeControlChars(str:gsub(spat, ""):gsub(epat, ""))
		end
	end

	if buf then
		t[#t + (#t > max and 0 or 1)] = decodeControlChars(buf)
	end

	return t
end

--- Takes an array of arguments and a max value.
function Util.MashExcessArguments(arguments, max)
	local t = {}
	for i = 1, #arguments do
		if i > max then
			t[max] = ("%s %s"):format(t[max] or "", arguments[i])
		else
			t[i] = arguments[i]
		end
	end
	return t
end

--- Trims whitespace from both sides of a string.
function Util.TrimString(s)
	return s:match "^%s*(.-)%s*$"
end

--- Returns the text bounds size
function Util.GetTextSize(text, label, size)
	return TextService:GetTextSize(text, label.TextSize, label.Font, size or Vector2.new(label.AbsoluteSize.X, 0))
end

--- Makes an Enum type.
function Util.MakeEnumType(name, values)
	local findValue = Util.MakeFuzzyFinder(values)
	return {
		Validate = function(text)
			return findValue(text, true) ~= nil, ("Value %q is not a valid %s."):format(text, name)
		end,
		Autocomplete = function(text)
			local list = findValue(text)
			return type(list[1]) ~= "string" and Util.GetNames(list) or list
		end,
		Parse = function(text)
			return findValue(text, true)
		end
	}
end

--- Parses a prefixed union type argument
function Util.ParsePrefixedUnionType(typeValue, rawValue)
	local split = Util.SplitStringSimple(typeValue)

	local types = {}
	for i = 1, #split, 2 do
		types[#types + 1] = {
			prefix = split[i - 1] or "",
			type = split[i]
		}
	end

	table.sort(
		types,
		function(a, b)
			return #a.prefix > #b.prefix
		end
	)

	for i = 1, #types do
		local t = types[i]

		if rawValue:sub(1, #t.prefix) == t.prefix then
			return t.type, rawValue:sub(#t.prefix + 1), t.prefix
		end
	end
end

--- Creates a listable type from a singlular type
function Util.MakeListableType(type, override)
	local listableType = {
		Listable = true,
		Transform = type.Transform,
		Validate = type.Validate,
		Autocomplete = type.Autocomplete,
		Parse = function(...)
			return {type.Parse(...)}
		end
	}

	if override then
		for key, value in pairs(override) do
			listableType[key] = value
		end
	end

	return listableType
end

local function encodeCommandEscape(text)
	return first(text:gsub("\\%$", string.char(20)))
end

local function decodeCommandEscape(text)
	return first(text:gsub(string.char(20), "$"))
end

--- Runs embedded commands and replaces them
function Util.RunEmbeddedCommands(dispatcher, str)
	str = encodeCommandEscape(str)

	local results = {}
	for text in str:gmatch("$(%b{})") do
		local doQuotes = true
		local commandString = text:sub(2, #text-1)

		if commandString:match("^{.+}$") then
			doQuotes = false
			commandString = commandString:sub(2, #commandString-1)
		end

		results[text] = dispatcher:EvaluateAndRun(commandString)

		if doQuotes and results[text]:find("%s") then
			results[text] = string.format("%q", results[text])
		end
	end

	return decodeCommandEscape(str:gsub("$(%b{})", results))
end

--- Replaces arguments in the format $1, $2, $something
function Util.SubstituteArgs(str, replace)
	str = encodeCommandEscape(str)
	if type(replace) == "table" then
		for i = 1, #replace do
			local k = tostring(i)
			replace[k] = replace[i]

			if replace[k]:find("%s") then
				replace[k] = string.format("%q", replace[k])
			end
		end
	end
	return decodeCommandEscape(str:gsub("($%d+)%b{}", "%1"):gsub("$(%w+)", replace))
end

--- Creates an alias command
function Util.MakeAliasCommand(name, commandString)
	local commandName, commandDescription = unpack(name:split("|"))
	local args = {}

	for arg in commandString:gmatch("$(%d+)") do
		local options = commandString:match("$" .. arg .. "{(.*)}")

		local argType, argName, argDescription
		if options then
			argType, argName, argDescription = unpack(options:split("|"))
		end

		argType = argType or "string"
		argName = argName or ("Argument " .. arg)
		argDescription = argDescription or ""

		table.insert(args, {
			Type = argType;
			Name = argName;
			Description = argDescription;
		})
	end

	return {
		Name = commandName,
		Aliases = {},
		Description = "<Alias> " .. (commandDescription or commandString),
		Group = "UserAlias",
		Args = args,
		Run = function(context)
			local commands = Util.SplitStringSimple(commandString, "&&")

			for i, command in ipairs(commands) do
				local output = context.Dispatcher:EvaluateAndRun(
					Util.RunEmbeddedCommands(
						context.Dispatcher,
						Util.SubstituteArgs(command, context.RawArguments)
					)
				)
				if i == #commands then
					return output
				else
					context:Reply(output)
				end
			end

			return ""
		end
	}
end

--- Makes a type that contains a sequence
function Util.MakeSequenceType(options)
	options = options or {}

	assert(options.Parse ~= nil or options.Constructor ~= nil, "MakeSequenceType: Must provide one of: Constructor, Parse")

	options.TransformEach = options.TransformEach or function(...)
		return ...
	end

	options.ValidateEach = options.ValidateEach or function()
		return true
	end

	return {
		Prefixes = options.Prefixes;

		Transform = function (text)
			return Util.Map(Util.SplitPrioritizedDelimeter(text, {",", "%s"}), function(value)
				return options.TransformEach(value)
			end)
		end;

		Validate = function (components)
			if options.Length and #components > options.Length then
				return false, ("Maximum of %d values allowed in sequence"):format(options.Length)
			end

			for i = 1, options.Length or #components do
				local valid, reason = options.ValidateEach(components[i], i)

				if not valid then
					return false, reason
				end
			end

			return true
		end;

		Parse = options.Parse or function(components)
			return options.Constructor(unpack(components))
		end
	}
end

--- Splits a string by a single delimeter chosen from the given set.
function Util.SplitPrioritizedDelimeter(text, delimeters)
	for i, delimeter in ipairs(delimeters) do
		if text:find(delimeter) or i == #delimeters then
			return Util.SplitStringSimple(text, delimeter)
		end
	end
end

--- Maps values of an array through a callback
function Util.Map(array, callback)
	local results = {}

	for i, v in ipairs(array) do
		results[i] = callback(v, i)
	end

	return results
end

--- Maps arguments #2-n through callback
function Util.Each(callback, ...)
	local results = {}
	for i, value in ipairs({...}) do
		results[i] = callback(value)
	end
	return unpack(results)
end

--- Emulates tabstops with spaces
function Util.EmulateTabstops(text, tabWidth)
	local result = ""
	for i = 1, #text do
		local char = text:sub(i, i)

		result = result .. (char == "\t" and string.rep(" ", tabWidth - #result % tabWidth) or char)
	end
	return result
end

return Util
