promise = {}
function promise.type(_type, default)
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
	function mt.__call(self,object)

		if object == nil then
			return default
		end
		if type(object) == _type or _type == "*" then
			return object
		elseif type(object) == "number" and _type == "int" then
			if object == math.floor(object) then return object end
		else
			return nil
		end
	end
	mt.__index = {default=default}
	return proxy
end

function promise.constant(constant)
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
	function mt.__call(self,object)
		if object == constant then
			return object
		end
	end
	return proxy
end

function promise.field(promises)
	--VALIDATOR
	local validator = newproxy(true)
	local mt = getmetatable(validator)
	function mt.__call(self, object)
		if promises.default then
			if object == nil then return self(promises.default) end
		end
		if promises.null then
			if object == nil then return nil end
		else
			if object == nil then return nil end
		end
		if promises.promise then
			if promises.promise(object, promises) then
				return object
			else
				return nil
			end
		end

		return object
	end
	mt.__index = promises
	function mt.__index.params()
		return pairs(mt.__index)
	end
	function mt.__newindex(self, k, v)
		if k == "name" then mt.__index.name = v end
	end
	return validator
end
