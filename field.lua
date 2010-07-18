if not model then
	-- We must have the model namespace to proceed
	error "Need to have model initiated before creating fields."
end


model.IntegerField = Field:new{
	type	= "IntegerField",
	promise = promise.type("int"),
	default = promise.type("int"),

	deserialize = function(object)
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

	serialize = function(object)
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
			sql = sql .. " DEFAULT " .. self.serialize(self.default)
		end
		return sql
	end
}

model.AutoField = Field:new{
	type	= "AutoField",
	pk 		= promise.type("boolean", false),
	promise = promise.type("int"),

	deserialize = function(object)
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

	serialize = function(object)
		if object == true then
			return "TRUE"
		elseif object == false then
			return "FALSE"
		end
	end,
	deserialize = function(object)
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
			sql = sql .. " DEFAULT " .. self.serialize(self.default)
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
	serialize = function(object)
		return table.concat(object, ";")
	end,
	deserialize = function(str)
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
			sql = sql .. " DEFAULT " .. self.serialize(self.default)
		end
		return sql
	end
}
