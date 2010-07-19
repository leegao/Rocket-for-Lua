require "model"

-- Make sure that model exists
assert(model, "Model namespace does not exist")

-- Create a sample user model with username, password, and usgn
User = model{
	"user", -- Table name, lowercase
	username = model.CharField{max_length = 10, null = false, unique = true},
	password = model.CharField{max_length = 10, null = false},
	usgn	 = model.IntegerField{null = true, unique = true}
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
	clan_name = model.CharField{unique = true},
	tag 	  = model.CharField{null = true}
}

-- Create a nice looking tostring of Clan
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

-- Create a nice looking tostring method of UserClan
function UserClan.on_string(self)
	return "%s%s"%{self.clan.tag or "[No Clan]", self.user.username}
end

-- Make sure that UserClan exists
assert(UserClan, "UserClan Proxy model cannot be created")

Model3 = model{"model3",data = model.CharField{}}

-- Create Proxies and go from there...
p = UserClan{user=lee,clan=TGV}

p:save()

aj = User{username = "aj", password = "aj"}
p2 = UserClan{user=aj,clan=TGV}
p2:save()

jack = User{username = "jack", password = "jack"}
jack:save()

-- Creates a query-set that finds all UserClan objects where clan.clan_name equals "TGV"
q = UserClan.objects.all():where{clan__clan_name = "TGV"}

-- Check that the queryset is constructed correctly
assert(q, "Queryset cannot be constructed")

-- Make sure that the Queryset can be evaluted
q()

q = User.objects.all():where{userclan__clan = TGV}
q()



-- Cleanup
p:delete()
p2:delete()
TGV:delete()
lee:delete()
aj:delete()
jack:delete()


sql:close()

-- Generated SQL:
--[[--
	>lua -e "io.stdout:setvbuf 'no'" "test.lua"
	SELECT * FROM sqlite_master WHERE tbl_name = "user_model";
	SELECT * FROM sqlite_master WHERE tbl_name = "clan_model";
	SELECT * FROM sqlite_master WHERE tbl_name = "userclan_model";
	INSERT INTO user_model (username,usgn,password) VALUES ("lee",146,"demo");
	SELECT id FROM user_model ORDER BY id DESC
	INSERT INTO clan_model (clan_name,tag) VALUES ("TGV","[TGV]");
	SELECT id FROM clan_model ORDER BY id DESC
	INSERT INTO userclan_model (user,clan) VALUES (1,1);
	SELECT id FROM userclan_model ORDER BY id DESC
	INSERT INTO user_model (password,username) VALUES ("aj","aj");
	SELECT id FROM user_model ORDER BY id DESC
	INSERT INTO userclan_model (user,clan) VALUES (2,1);
	SELECT id FROM userclan_model ORDER BY id DESC
	INSERT INTO user_model (password,username) VALUES ("jack","jack");
	SELECT id FROM user_model ORDER BY id DESC
	SELECT * FROM clan_model WHERE ( "clan_name" = "TGV" )
	SELECT * FROM userclan_model WHERE ( "clan" = 1 )
	SELECT * FROM clan_model WHERE ( "id" = 1 ) LIMIT 1
	SELECT * FROM user_model WHERE ( "id" = 1 ) LIMIT 1
	SELECT * FROM clan_model WHERE ( "id" = 1 ) LIMIT 1
	SELECT * FROM user_model WHERE ( "id" = 2 ) LIMIT 1
	SELECT user AS id FROM userclan_model WHERE ( "clan" LIKE 1 ESCAPE '\' )
	SELECT * FROM user_model WHERE ( "id" = 1 ) LIMIT 1
	SELECT * FROM user_model WHERE ( "id" = 2 ) LIMIT 1
	DELETE FROM userclan_model WHERE id=1
	DELETE FROM userclan_model WHERE id=2
	DELETE FROM clan_model WHERE id=1
	DELETE FROM user_model WHERE id=1
	DELETE FROM user_model WHERE id=2
	DELETE FROM user_model WHERE id=3
	>Exit code: 0
--]]--
