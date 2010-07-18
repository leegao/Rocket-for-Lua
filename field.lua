if not model then
	-- We must have the model namespace to proceed
	error "Need to have model initiated before creating fields."
end

local Field__mt = {}

Field__mt.__index = {
	null 	= promise.type("boolean", false),
	default	= promise.type("*"),
	editable= promise.type("boolean", true),
	help	= promise.type("string", "Potions Field"),
	pk		= promise.type("boolean", false),
	unique	= promise.type("boolean", false),
	name	= promise.type("string"),
	type	= "Field",
}

local Field = {
	new = function(this, args)
		local mt = {}
		function mt.__newindex(self, key, val)
			self.addons[key] = val
		end
		function mt.__call(self, params)
			local seen = {}
			local promises = {promise = args.promise, type = args.type}

			for _,positional in ipairs(params) do
				seen[_] = true
				--pass
			end

			for key,var in pairs(params) do
				if not seen[key] then
					local _promise = self[key]
					if _promise then
						if _promise(var) ~= nil then
							promises[key] = _promise(var)
						else
							error "Wrong Type"
						end
					end
					if key:sub(1, 3) == "on_" or key == "serialize" or key == "deserialize" or name == "sql" then
						promises[key] = var
					end
					seen[key] = true
				end
			end

			for name,field in pairs(self.addons) do
				if not seen[name] then
					seen[name] = true
					if type(field) ~= "function" then
						if field.default then promises[name] = field.default end
					end
					if name:sub(1, 3) == "on_" or name == "serialize" or name == "deserialize" or name == "sql" then
						promises[name] = field
					end
				end
			end

			for name,field in pairs(self.index) do
				if not seen[name] then
					seen[name] = true
					if field.default then promises[name] = field.default end
				end
			end
			--print(dump(promises))
			return promise.field(promises)
		end
		function mt.__index(self, key)
			if key == "addons" then return rawget(self,"addons") end
			if key == "index" then return getmetatable(this).__index end
			local tab2 = getmetatable(this).__index
			local tab1 = rawget(self,"addons")
			if tab1[key] then return tab1[key] else return tab2[key] end
		end
		local field = {new=this.new, addons={}}
		setmetatable(field, mt)
		if args.promise then
			rawset(field, "promise", args.promise)
		end
		if args.serialize then
			rawset(field, "serialize", args.serialize)
			field.addons.serialize = args.serialize
		end
		if args.deserialize then
			rawset(field, "deserialize", args.deserialize)
			field.addons.deserialize = args.deserialize
		end
		if args.sql then
			rawset(field, "sql", args.sql)
			field.addons.sql = args.sql
		end
		for k,v in pairs(args) do if k ~= "promise" then field[k] = v end end
		return field
	end
}
setmetatable(Field, Field__mt)

model.IntegerField = Field:new{
	type	= "IntegerField",
	promise = promise.type("int"),
	default = promise.type("int"),

	deserialize = function(self,object)
		return tonumber(object)
	end,

	sql = function(self, field)
		local sql = self.field_name .. " INTEGER"
		if self.pk then
			sql = sql .. " PRIMARY KEY"
		end
		if self.unique then
			sql = sql .. " UNIQUE"
		end
		if not self.null then
			sql = sql .. " NOT NULL"
		end
		if self.default then
			sql = sql .. " DEFAULT " .. tostring(self.default)
		end
		return sql
	end
}

model.CharField = Field:new{
	type 	= "CharField",
	promise = function(object, promises)
		local result = promise.type("string")(object)
		if not result then return result end
		if #result > promises.max_length then return nil end
		return result
	end,
	max_length = promise.type("int", 50),

	serialize = function(self,object)
		return '"'..object:gsub('"','\\"')..'"'
	end,

	sql = function(self, field)
		local sql = self.field_name .. " VARCHAR("..tostring(self.max_length)..")"
		if self.unique then
			sql = sql .. " UNIQUE"
		end
		if not self.null then
			sql = sql .. " NOT NULL"
		end
		if self.default then
			sql = sql .. " DEFAULT " .. self:serialize(self.default)
		end
		return sql
	end
}

model.AutoField = Field:new{
	type	= "AutoField",
	pk 		= promise.type("boolean", false),
	promise = promise.type("int"),

	deserialize = function(self,object)
		return tonumber(object)
	end,

	sql = function(self, field)

		local sql = self.field_name .. " INTEGER"
		if self.pk then
			sql = sql .. " PRIMARY KEY"
		end
		if self.unique then
			sql = sql .. " UNIQUE"
		end
		if not self.null then
			sql = sql .. " NOT NULL"
		end
		if self.default then
			sql = sql .. " DEFAULT " .. tostring(self.default)
		end
		return sql
	end
}

model.BooleanField = Field:new{
	type	= "BooleanField",
	promise = promise.type("boolean"),
	default = promise.type("boolean"),

	serialize = function(self,object)
		if object == true then
			return "TRUE"
		elseif object == false then
			return "FALSE"
		end
	end,
	deserialize = function(self,object)
		if object:lower() == "true" then return true else return false end
	end,

	sql = function(self, field)
		local sql = self.field_name .. " BOOLEAN"
		if self.unique then
			sql = sql .. " UNIQUE"
		end
		if not self.null then
			sql = sql .. " NOT NULL"
		end
		if self.default then
			sql = sql .. " DEFAULT " .. self:serialize(self.default)
		end
		return sql
	end
}

model.CommaSeparatedIntegerField = Field:new{
	type	= "CommaSeparatedIntegerField",
	max_length = promise.type("integer", 50),
	promise = function(object, promises)
		local result = promise.type("table")(object)
		if not result then return nil end
		if #result > promises.max_length then return nil end
		for _,v in ipairs(object) do
			if not promise.type("int")(v) then return nil end
		end
		return result
	end,
	serialize = function(self,object)
		return table.concat(object, ";")
	end,
	deserialize = function(self,str)
		local stack = {}
		for w in string.gmatch(str, "[^;]+") do table.insert(stack, w) end
		return stack
	end,

	sql = function(self, field)
		local sql = self.field_name .. " VARCHAR("..tostring(self.max_length*5)..")"
		if self.unique then
			sql = sql .. " UNIQUE"
		end
		if not self.null then
			sql = sql .. " NOT NULL"
		end
		if self.default then
			sql = sql .. " DEFAULT " .. self:serialize(self.default)
		end
		return sql
	end
}

model.ForeignKey = Field:new{
	type	= "ForeignKey",
	to		= promise.type("*"),
	promise = function(object, promises)
		local ref
		if type(promises.to) == "string" then
			if promises.to:sub(#(promises.to)-6) ~= "_model" then
				ref = promises.to .. "_model"
			else
				ref = promises.to
			end
			if model.static[ref] then
				promises.to = model.static[ref]
			else
				return nil
			end
		end

		if type(object) ~= "table" then return nil end
		if not object.super then return nil end

		if object.super.model_name ~= promises.to.model_name then
			return nil
		end
		return object
	end,

	serialize = function(self,object)
		return tostring(object.id)
	end,
	deserialize = function(self,str)
		local id = tonumber(str)
		local object = self.to
		if type(object) == "string" then
			object = model.static[object.."_model"]
		end
		return object.objects.get{id=id}
	end,

	on_save = function(self, this)
		if not self[this].id then
			self[this]:save()
		end
	end,
	on_create = function(self, this)
		local object = self.to
		if type(object) == "string" then
			if object:sub(#object-4) ~= "_model" then
				object = object.."_model"
			end
		elseif type(object) == "table" then
			object = object.model_name
		end
		print(self.super.model_name)
		local defer
		if not model.static[object] then
			defer = true
		end
		if not defer then
			model.static[object].static.foreign[this] = self.super
		else
			if not model.defered[object] then
				model.defered[object] = {}
			end
			table.insert(model.defered[object], function(Model)
				Model.static.foreign[this] = self.super
			end)
		end
	end,

	sql = function(self, field)
		local sql = self.field_name .. " INTEGER"
		if self.unique then
			sql = sql .. " UNIQUE"
		end
		if not self.null then
			sql = sql .. " NOT NULL"
		end
		if self.default then
			sql = sql .. " DEFAULT " .. tostring(self.default)
		end
		return sql
	end
}
