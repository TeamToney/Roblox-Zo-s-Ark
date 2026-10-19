--!strict
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules").new(Catalog, Config)
local ProfileStore: any = require("../src/server/ProfileStore")
local passed, failed = 0, 0
local function test(name: string, callback: () -> ())
	local ok, problem = pcall(callback)
	if ok then passed += 1; print("PASS  " .. name)
	else failed += 1; print("FAIL  " .. name .. ": " .. tostring(problem)) end
end
local function equal(actual: any, expected: any)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end
local function fixture(temporary: boolean?)
	local records: {[string]: any} = {}
	local db: any = {calls = 0, failures = 0, opens = 0}
	function db.UpdateAsync(self: any, key: string, transform: any)
		self.calls += 1
		if self.failures > 0 then self.failures -= 1; error("injected service failure") end
		local nextRecord = transform(copy(records[key]))
		if nextRecord ~= nil then records[key] = copy(nextRecord) end
		return copy(nextRecord)
	end
	local now, tokens = 1800000000, 0
	local adapter: any = {
		temporary = temporary == true,
		openStore = function(name: string)
			equal(name, Config.DataStoreName)
			db.opens += 1
			return db
		end,
		now = function() return now end,
		clock = function() return now end,
		sleep = function(seconds: number) now += seconds end,
		warn = function(...: any) end,
		newToken = function() tokens += 1; return "session-" .. tokens end,
	}
	return {records = records, db = db, adapter = adapter, store = ProfileStore.new(Rules, Config, adapter), advance = function(seconds: number) now += seconds end}
end

test("a new live journal is atomically created with a lease", function()
	local f = fixture(); local session = assert(f.store:load(1))
	equal(f.db.opens, 1)
	equal(session.data.coins, 100); equal(f.records.u_1.schema, Config.SchemaVersion)
	equal(f.records.u_1.lease.token, session.token)
	equal(f.records.u_1.lease.expires, f.adapter.now() + Config.LeaseSeconds)
end)
test("a second writer cannot open an active leased profile", function()
	local f = fixture(); local first = assert(f.store:load(1))
	equal(f.store:load(1), nil)
	equal(f.records.u_1.lease.token, first.token); equal(f.records.u_1.data.coins, 100)
end)
test("an expired lease can be replaced without resetting data", function()
	local f = fixture(); local first = assert(f.store:load(1))
	first.data.coins = 432; assert(f.store:save(first, false))
	f.advance(Config.LeaseSeconds + 1)
	local second = assert(f.store:load(1))
	assert(second.token ~= first.token); equal(second.data.coins, 432)
end)
test("a former owner cannot overwrite a profile after its lease is replaced", function()
	local f = fixture(); local first = assert(f.store:load(1))
	f.advance(Config.LeaseSeconds + 1); local second = assert(f.store:load(1))
	first.data.coins = 999999
	equal(f.store:save(first, false), false); equal(first.lost, true)
	equal(f.records.u_1.data.coins, 100); equal(f.records.u_1.lease.token, second.token)
end)
test("autosave copies profile data and renews only the owner's lease", function()
	local f = fixture(); local session = assert(f.store:load(1))
	f.advance(60); session.data.coins = 222; session.data.inventory.rabbit = 2
	assert(f.store:save(session, false))
	equal(f.records.u_1.data.coins, 222)
	equal(f.records.u_1.lease.expires, f.adapter.now() + Config.LeaseSeconds)
	session.data.inventory.rabbit = 3
	equal(f.records.u_1.data.inventory.rabbit, 2)
	equal(session.lastSaved, f.adapter.now())
end)
test("release saves the final journal and allows an immediate reconnect", function()
	local f = fixture(); local session = assert(f.store:load(1)); session.data.coins = 700
	assert(f.store:save(session, true)); equal(session.closed, true); equal(f.records.u_1.lease, nil)
	local nextSession = assert(f.store:load(1)); equal(nextSession.data.coins, 700)
	equal(f.store:save(session, false), false)
end)
test("future save schemas are rejected and left intact", function()
	local f = fixture()
	f.records.u_1 = {schema = Config.SchemaVersion + 1, data = {coins = 777}}
	equal(f.store:load(1), nil); equal(f.records.u_1.data.coins, 777)
	equal(f.records.u_1.lease, nil)
end)
test("malformed records are rejected rather than replaced with new journals", function()
	local f = fixture(); f.records.u_1 = "corrupt"
	equal(f.store:load(1), nil); equal(f.records.u_1, "corrupt")
	f.records.u_1 = {schema = Config.SchemaVersion, data = false}
	equal(f.store:load(1), nil); equal(f.records.u_1.data, false)
end)
test("transient DataStore errors are retried and recover", function()
	local f = fixture(); f.db.failures = 2
	local session = assert(f.store:load(1))
	equal(f.db.calls, 3); equal(session.data.coins, 100)
end)
test("exhausted load retries do not create a blank persisted record", function()
	local f = fixture(); f.db.failures = 3
	equal(f.store:load(1), nil); equal(f.db.calls, 3); equal(f.records.u_1, nil)
end)
test("failed autosaves retain the previous stored journal and retry later", function()
	local f = fixture(); local session = assert(f.store:load(1))
	local lastSaved = session.lastSaved
	session.data.coins = 500; f.db.failures = 3
	equal(f.store:save(session, false), false)
	equal(f.records.u_1.data.coins, 100); equal(session.lastSaved, lastSaved)
	equal(session.lost, false); equal(session.saving, false)
	assert(f.store:save(session, false)); equal(f.records.u_1.data.coins, 500)
end)
test("temporary Studio journals never read or write the persistent store", function()
	local f = fixture(true); local session = assert(f.store:load(1))
	session.data.coins = 1000; assert(f.store:save(session, false)); assert(f.store:save(session, true))
	equal(f.db.opens, 0); equal(f.db.calls, 0); equal(f.records.u_1, nil)
	local nextSession = assert(f.store:load(1)); equal(nextSession.data.coins, 100)
end)
test("temporary journals work when opening the online store would throw", function()
	local f = fixture(true)
	f.adapter.openStore = function() error("Publish this place before accessing DataStore") end
	local store = ProfileStore.new(Rules, Config, f.adapter)
	local session = assert(store:load(1))
	equal(session.temporary, true); equal(session.data.coins, 100)
	session.data.coins = 200
	assert(store:save(session, false)); assert(store:save(session, true))
	equal(f.db.opens, 0); equal(f.db.calls, 0)
	equal(assert(store:load(1)).data.coins, 100)
end)
test("live store acquisition failures do not fall back to temporary journals", function()
	local f = fixture(true)
	f.adapter.temporary = false
	f.adapter.openStore = function() error("Online store unavailable") end
	local ok = pcall(function() ProfileStore.new(Rules, Config, f.adapter) end)
	equal(ok, false); equal(f.db.calls, 0)
end)
test("a release waits for an in-flight save and then writes final progress", function()
	local f = fixture(); local session = assert(f.store:load(1)); session.data.coins = 555
	session.saving = true
	f.adapter.sleep = function(seconds: number) f.advance(seconds); session.saving = false end
	assert(f.store:save(session, true)); equal(f.records.u_1.data.coins, 555); equal(f.records.u_1.lease, nil)
end)
test("a canceled write after external schema change cannot erase that record", function()
	local f = fixture(); local session = assert(f.store:load(1))
	f.records.u_1 = {schema = 99, data = {coins = 1234}}
	equal(f.store:save(session, false), false); equal(session.lost, true)
	equal(f.records.u_1.schema, 99); equal(f.records.u_1.data.coins, 1234)
end)

print(string.format("\n%d profile-store cases passed, %d failed (injected service adapter, not live DataStore)", passed, failed))
if failed > 0 then error("Zo's Ark profile-store checks failed") end
