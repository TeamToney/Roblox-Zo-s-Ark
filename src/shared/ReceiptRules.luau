--!strict
-- The Marketplace callback acknowledges only a successfully saved receipt.
-- A failed write leaves the grant + marker in memory for a safe retry.
local ReceiptRules = {}
function ReceiptRules.process(session: any, purchaseId: any, product: string?, rules: any, save: any): boolean
	if not session or session.closed or session.lost or session.temporary or session.saving or not product then return false end
	if type(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > 200 then return false end
	if not session.data.receipts[purchaseId] then
		if not rules.grantProduct(session.data, product) then return false end
		session.data.receipts[purchaseId] = true
	end
	return save(session) == true
end
return ReceiptRules
