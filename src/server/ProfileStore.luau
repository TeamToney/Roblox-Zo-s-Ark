--!nonstrict
local ProfileStore = {}
ProfileStore.__index = ProfileStore

local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = clone(child) end
	return result
end

local function retry(operation, adapter)
	local lastError
	for attempt = 1, 3 do
		local ok, result = pcall(operation)
		if ok then return true, result end
		lastError = result
		if attempt < 3 then adapter.sleep(attempt) end
	end
	adapter.warn("[Zo's Ark] DataStore operation failed:", lastError)
	return false, nil
end

-- Services are injected so ownership and failure handling can be fault-tested
-- without pretending to run the Roblox engine or its live DataStore service.
function ProfileStore.new(rules, config, adapter)
	-- Unpublished Studio files cannot acquire a DataStore. Temporary journals
	-- must skip acquisition itself, as well as every persistent read and write.
	local store
	if not adapter.temporary then store = adapter.openStore(config.DataStoreName) end
	return setmetatable({
		rules = rules,
		config = config,
		store = store, adapter = adapter,
		temporary = adapter.temporary,
	}, ProfileStore)
end

function ProfileStore:load(userId)
	local token = self.adapter.newToken()
	local session = {
		key = "u_" .. userId, token = token, data = nil,
		temporary = self.temporary, saving = false, closed = false, lost = false,
		lastSaved = self.adapter.now(),
	}
	if self.temporary then
		session.data = self.rules.blank(self.adapter.now())
		return session
	end
	local ok, record = retry(function()
		return self.store:UpdateAsync(session.key, function(previous)
			local now = self.adapter.now()
			if previous ~= nil then
				-- Unknown versions and malformed records require investigation, not a reset.
				if type(previous) ~= "table" or previous.schema ~= self.config.SchemaVersion or type(previous.data) ~= "table" then return nil end
				local lease = previous.lease
				if type(lease) == "table" and type(lease.expires) == "number" and lease.expires > now and lease.token ~= token then return nil end
			end
			return {
				schema = self.config.SchemaVersion,
				data = if previous then previous.data else self.rules.blank(now),
				lease = {token = token, expires = now + self.config.LeaseSeconds},
			}
		end)
	end, self.adapter)
	if not ok or not record or not record.lease or record.lease.token ~= token then
		return nil, "Your Ark journal could not be opened safely. A previous session may still be saving. Please rejoin in a few minutes."
	end
	session.data = self.rules.sanitize(record.data, self.adapter.now())
	return session
end

function ProfileStore:save(session, release)
	if release then
		local deadline = self.adapter.clock() + 12
		while session.saving and self.adapter.clock() < deadline do self.adapter.sleep(0.1) end
	end
	if session.closed or session.saving or session.lost then return false end
	if session.temporary then
		session.lastSaved = self.adapter.now()
		if release then session.closed = true end
		return true
	end
	session.saving = true
	local snapshot = clone(session.data)
	local ok, record = retry(function()
		return self.store:UpdateAsync(session.key, function(previous)
			if type(previous) ~= "table" or previous.schema ~= self.config.SchemaVersion then return nil end
			if type(previous.lease) ~= "table" or previous.lease.token ~= session.token then return nil end
			return {
				schema = self.config.SchemaVersion,
				data = snapshot,
				lease = if release then nil else {token = session.token, expires = self.adapter.now() + self.config.LeaseSeconds},
			}
		end)
	end, self.adapter)
	session.saving = false
	-- A successful API call with no record means ownership was lost. Never overwrite.
	if ok and not record then session.lost = true end
	if ok and record then session.lastSaved = self.adapter.now() end
	if release then session.closed = true end
	return ok and record ~= nil
end

return ProfileStore
