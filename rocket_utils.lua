--[[--
	General sets of tools used during development. These can later be abstracted out of the full source code and be discarded.
	NOTE: Convenience use only, do not use as pre-requisites.
--]]--


local gm = debug.getmetatable("") -- Common metatable for strings

-- STRING%obj or STRING%{a,b,c} -> STRING:format(a,b,c) for convenient syntax sugar.
gm.__mod=function(self, other)
	if type(other) ~= "table" then other = {other} end
	for i,v in ipairs(other) do other[i] = tostring(v) end
	return self:format(unpack(other))
end

-- Splits a string based on pattern pat.
function string:split(pat)
	pat = pat or '%s+'
	local st, g = 1, self:gmatch("()("..pat..")")
	local function getter(segs, seps, sep, cap1, ...)
		st = sep and seps + #sep
		return self:sub(segs, (seps or 0) - 1), cap1 or sep, ...
	end
	local iter = function() if st then return getter(st, g()) end end
	local stack = {}
	for w in iter do table.insert(stack, w) end
	return stack
end

-- str:inside{"1","2","3"} checks to see if str is any of the elements of the table.
function string.inside(o, t)
	for i, v in ipairs(t) do
		if o==v then return true end
	end
	return false
end

-- Returns a string serialization of a table that is verbosely and recursively introspected.
function dump(list)
	local str = "{"
	local seen = {}
	for _,v in ipairs(list) do
		if type(v) ~= "table" then
			str = str .. tostring(v) .. ", "
		else
			str = str .. dump(v) .. ", "
		end
		seen[_] = true
	end
	if #list > 0 then
		str = str:sub(1, #str-2)
	end
	local trim = false
	for k,v in pairs(list) do
		if not seen[k] then
			trim = true
			if type(v) ~= "table" then
				str = str .. tostring(k) .. " = " .. tostring(v) .. ", "
			else
				str = str .. tostring(k) .. " = " .. dump(v) .. ", "
			end
		end
	end
	if trim then str = str:sub(1, #str-2) end
	str = str .. "}"
	return str
end

-- Returns an iterator for a table by index. The index is not returned as the first parameter.
function list_iter (t)
	local i = 0
	local n = table.getn(t)
	return function ()
		i = i + 1
		if i <= n then return t[i] end
	end
end

function tostring_(_,obj)
	return tostring(obj)
end
