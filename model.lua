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

require "luasql.sqlite3"
sql = luasql.sqlite3
env = sql()

con = assert (env:connect("test.db"))

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


model = {}

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

function model.Model(self, fields)
	if not fields.id then fields.id = model.AutoField{pk = true} end
	if not fields[1] then error "Model must be named" end
	local Model = {static = {}, on = {}, model_name = fields[1].."_model"}
	local mt = {}

	table.remove(fields, 1)



	function mt.__call(self, args)
		--Construct a new lazy model
		local all = {}
		for field, value in pairs(args) do
			if fields[field] then
				if type(value) == "string" and fields[field].deserialize then
					value = fields[field].deserialize(value)
					args[field] = value
				end
				local validate =  fields[field](value)
				if validate ~= nil or fields[field].null then
					all[field] = validate
				end
			end
		end
		for field, validator in pairs(fields) do
			--validator.name = field
			--rawset(getmetatable(validator).__index, "field_name", field)
			if not all[field] then all[field] = validator() end
		end

		local modelInstance = {all=all, on = self.on, super = self}
		local imt = {}
		function imt.__index(self, key)

			return self.all[key]
		end

		function imt.__newindex(self, key, val)
			if fields[key] then
				if fields[key](val) then
					self.all[key] = fields[key](val)
				end
			end

		end

		function imt.__eq(self, other)
			return self.id == other.id
		end

		function imt.__tostring(self)
			if self.super.on.string then
				return self.super.on.string(self)
			end
			return tostring("<%s Instance@%s>"%{self.super.model_name, self.id or "NaN"})
		end

		function modelInstance.save(self)
			if self.on.save then
				local r = self.on.save(self)
				if r then return end
			end
			for field, validator in pairs(fields) do
				if validator.on_save then
					validator.on_save(self)
				end

				if not validator.null then
					if not self[field] and not validator.pk then
						error("Improper Field: "..field.." failed the validation.")
					end
				end
			end

			--SAVE
			local insert = true
			if self.id then
				insert = false
			end
			local stack = {}
			local fieldstack = {}
			local objectstack = {}
			for field,object in pairs(self.all) do
				if fields[field].serialize then
					object = fields[field].serialize(object)
				else
					object = tostring(object)
				end
				table.insert(stack, field.."="..object)
				table.insert(fieldstack, field)
				table.insert(objectstack, object)
			end
			local stmt = "UPDATE %s SET %s WHERE id=%s;"
			stmt = stmt:format(Model.model_name, table.concat(stack, ","), tostring(self.id))
			if insert then
				stmt = "INSERT INTO %s (%s) VALUES (%s);"
				stmt = stmt:format(Model.model_name, table.concat(fieldstack,","), table.concat(objectstack,","))
			end

			--print(stmt)
			assert(con:execute(stmt))

			if insert then
				local cur = con:execute("SELECT id FROM "..Model.model_name .. " ORDER BY id DESC")
				self.id = tonumber(cur:fetch())
			end
		end

		function modelInstance.delete(self)
			--CHECK FOR FOREIGN DEPENDENCIES

			--Make sure self exists
			if self.id then
				local sql = "DELETE FROM %s WHERE id=%s"%{self.super.model_name, self.id}
				print(sql)
				assert(con:execute(sql))
			end

			setmetatable(self, nil)
			for k in pairs(self) do rawset(self,k,nil) end
			self = nil
		end

		setmetatable(modelInstance, imt)
		return modelInstance
	end


	function Model.sync_db(self)
		--con:execute "CREATE TABLE meta (id INTEGER PRIMARY KEY, data TEXT)"
		local cur = con:execute(string.format("select * from sqlite_master where tbl_name = \"%s\";", self.model_name))
		if not cur:fetch() then
			--Need to setup the model in the database
			local stack = {}
			for field, validator in pairs(fields) do
				if(validator.sql)then
					local part = validator:sql(field)
					if not part then error("Cannot Create the DATABASE for model "..self.model_name.. "'s field "..field) end
					table.insert(stack,part)
				else
					error("Need a sql() function for model "..self.model_name.. "'s field "..field)
				end
			end
			local sql = string.format("CREATE TABLE %s (%s);", self.model_name, table.concat(stack, ", "))
			--print(sql)
			assert(con:execute(sql))
		end
	end

	--QuerySet mt
	local qmt = {}
	function qmt.__call(self)
		local sql = self.sql
		local stack = {self.select, self.table}
		if self._where then
			sql = sql .. " WHERE"
			for key, where in pairs(self._where) do
				sql = sql .. " \"%s\""
				table.insert(stack, key)
				if where.exact then
					sql = sql .. " = %s"
					table.insert(stack, where.obj)
				elseif where.flag then
					sql = sql .. " %s %s"
					table.insert(stack, where.flag)
					table.insert(stack, where.obj)
				else
					sql = sql .. ' LIKE %s ESCAPE \'\\\''
					table.insert(stack, where.obj)
				end
				sql = sql .. " AND"
			end
			sql = sql:sub(1,#sql-4)
		end
		if self._order_by then
			sql = sql .. " ORDER BY"
			for key, ordering in pairs(self._order_by) do
				sql = sql .. ' "%s" %s,'
				table.insert(stack, key)
				table.insert(stack, ordering:upper())
			end
			sql = sql:sub(1, #sql-1)
		end
		if self._limit then
			sql = sql .. " LIMIT %s"
			table.insert(stack, self._limit)
		end
		if self._offset then
			sql = sql .. " OFFSET %s"
			table.insert(stack, self._offset)
		end
		print(sql%stack)
		local cur = con:execute(sql%stack)
		local results = {}
		local row = cur:fetch({},"a")
		while row do
			table.insert(results, Model(row))
			row = cur:fetch({},"a")
		end
		results.iter = list_iter
		setmetatable(results, {__tostring=dump})
		return results
	end

	--DEFAULT MANAGER
	Model.objects = {}
	function Model.objects.all()
		local sql = "SELECT %s FROM %s"
		local self = {}
		self.sql = sql
		self.select = "*"
		self.table = Model.model_name

		function self.where(self, args)
			if not self._where then self._where = {} end
			local where
			for field,expr in pairs(args) do
				where = {}
				local s = field:split("__")
				field = s[1]
				local flags = {select(2, unpack(s))}
				if Model.fields[field] then
					local val = Model.fields[field]
					if val(expr) then
						if #flags == 0 then
							where.exact = true
							where.obj = (val.serialize or tostring)(expr)
						else
							local flag = flags[1]
							if flag == "startswith" then
								expr = expr .. "%"
							elseif flag == "endswith" then
								expr = "%"..expr
							elseif flag == "contains" then
								expr = "%"..expr.."%"
							elseif flag == "gt" then
								where.flag = ">"
							elseif flag == "ge" then
								where.flag = ">="
							elseif flag == "lt" then
								where.flag = "<"
							elseif flag == "le" then
								where.flag = "<="
							end
							where.obj = (val.serialize or tostring)(expr)
						end

					else
						error("Cannot validate field %s with expr %s"%{field, expr})
					end
				else
					error("Field does not exist: %s"%field)
				end
				self._where[field] = where
			end
			return self
		end
		function self.order_by(self, args)
			if not self._order_by then self._order_by = {} end
			local order_by
			for field,expr in pairs(args) do
				if Model.fields[field] then
					if expr:lower():inside{"asc", "ascending", "+"} then
						order_by = "ASC"
					else
						order_by = "DESC"
					end
				end
				self._order_by[field] = order_by
			end
			return self
		end
		function self.limit(self, n)
			if n then self._limit = n end
			return self
		end
		function self.offset(self, n)
			if n then self._offset = n end
			return self
		end
		setmetatable(self, qmt)
		return self
	end

	function mt.__newindex(self, key, val)
		if key:sub(1,3) == "on_" then
			self.on[key:sub(4)] = val
			return
		end

		if type(val) == "function" then
			rawset(self, key, val)
		end
	end

	setmetatable(Model, mt)

	for field, validator in pairs(fields) do
		rawset(getmetatable(validator).__index, "field_name", field)
		rawset(getmetatable(validator).__index, "super", Model)
	end

	rawset(Model, "fields", fields)


	return Model
end

setmetatable(model, {__call = model.Model})

Person = model{
	"Person",
	name 	= model.CharField{},
}

Band = model{
	"Band",
	band_name = model.CharField{max_length = 20},
	website = model.CharField{max_length = 100, null = true, default = "http://example.com/"},
}

function Band.on_string(self)
	return "<Band: %s>"%(self.band_name or self.id or "NaN")
end

Band:sync_db()
Person:sync_db()

--print(Band.fields.band_name.super.fields.website.type)
b = Band{band_name = "basdf"}
b.website = "omg.com"
b:save()
b:delete()
q = Band.objects.all():order_by{id="+"}()
for o in q:iter() do
	print(o)
end
