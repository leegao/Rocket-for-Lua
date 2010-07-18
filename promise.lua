--[[--
	Functions contained within the promise namespace aids in writing lazily evaluated objects.
	Objects created by promises are usually bearers of certain conditions that allows object creation
	to be deferred until all of the pieces of the puzzle are present.

	@VOLATILE API, subjected to change so do not use unless necessary. These are useful for defining
	new field types for Rocket models.
--]]--

promise = {} -- Namespace

--~ Developer's Note:
--~ The return values of any given promise is implemented as a callable userdata.
--~ The idea behind this is that userdata can be associated with a __gc metamethod
--~ to alert the model of its own garbage collection. This will probably change in the future.

--=--=--=--=--=--=--=--=--=--=--=--=--=--

--~ Promise.type returns a validator for a specific lua type. It also incorporates integers.
--~ @param _type in "string", "boolean", "table", "number", and "int"
--~ @param default is an instance of type '_type'
function promise.type(_type, default)
	local validator = newproxy(true)
	local mt = getmetatable(validator)
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
	return validator
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
