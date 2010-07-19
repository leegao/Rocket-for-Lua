require "model"

-- Make sure that model exists
assert(model, "Model namespace does not exist")

-- Create a sample user model with username, password, and usgn
User = model{
	"user", -- Table name, lowercase
	username = model.CharField{max_length = 10, null = false},
	password = model.CharField{max_length = 10, null = false},
	usgn	 = model.IntegerField{null = true, default = 0}
}

-- Make sure that User is created
assert(User, "Cannot create model User")

-- Create a user
lee = User{username = "lee", password = "confidential"}

-- Check that lee exists
assert(lee, "Cannot create user lee")

-- Check that lee's password is too long
assert(not lee.password, "confidential is somehow less than 10 letters long.")

-- Check that lee doesn't have an id yet.
assert(not lee.id, "Object lee has been tempered with")

-- Assign a usgn to lee and validate
lee.usgn = 146
-- Assign a valid password
lee.password = "demo"

-- Validate usgn
assert(lee.usgn == 146, "Object lee's USGN is incorrect")

-- Create a sample clan model with clan_name and tag fields
Clan = model{
	"clan",
	clan_name = model.CharField{},
	tag 	  = model.CharField{null = true}
}
function Clan.on_string(self)
	return self.tag or "[NaN]"
end

-- Make sure that Clan is created
assert(Clan, "Cannot create model Clan")

-- Create a clan
TGV = Clan{clan_name = "TGV", tag = "[TGV]"}

-- Check TGV
assert(TGV, "Cannot create clan TGV")

-- Create a userproxy to connect user to clan
UserClan = model{
	"userclan",
	clan = model.ForeignKey{to = "clan", null = false},
	user = model.ForeignKey{to = "user", null = false}
}
function UserClan.on_string(self)
	return "%s%s"%{self.clan.tag or "[No Clan]", self.user.username}
end
assert(UserClan)

p = UserClan{user=lee,clan=TGV}

p:save()

aj = User{username = "aj", password = "aj"}
p2 = UserClan{user=aj,clan=TGV}
p2:save()

jack = User{username = "jack", password = "jack"}
jack:save()

q = UserClan.objects.all():where{clan__clan_name = "TGV"}

print(q())

--Cleanup
p:delete()
p2:delete()
TGV:delete()
lee:delete()
aj:delete()
jack:delete()

env:close()
