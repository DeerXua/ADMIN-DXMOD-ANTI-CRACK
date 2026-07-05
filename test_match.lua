local data = '{"status":"success","active":true,"message":"Device activated","expires_at":"2026-08-04T14:46:45.093Z"}'
local resLower = string.lower(data)
local active = (resLower:match('"active"%s*:%s*true') ~= nil)
print("Pattern match result:", active)

local expires_at = data:match('"expires_at"%s*:%s*"([^"]+)"') or data:match('"expiresAt"%s*:%s*"([^"]+)"')
print("Expires at:", expires_at)
