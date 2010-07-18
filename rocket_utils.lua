local gm = debug.getmetatable("")

gm.__mod=function(self, other)
	if type(other) ~= "table" then other = {other} end
	for i,v in ipairs(other) do other[i] = tostring(v) end
	return self:format(unpack(other))
end

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

function string.inside(o, t)
	for i, v in ipairs(t) do
		if o==v then return true end
	end
	return false
end

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

function list_iter (t)
	local i = 0
	local n = table.getn(t)
	return function ()
		i = i + 1
		if i <= n then return t[i] end
	end
end
