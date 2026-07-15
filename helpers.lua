-- A vendored helper module for prova-rabbitmq, required by rabbitmq.lua as `require("rabbitmq.helpers")`
-- (namespaced by the plugin's canonical name). Plugins are self-contained — helpers ship inside the
-- plugin's own repo and version as one unit with it; there is no external dependency resolution.

local helpers = {}

-- Single-quote a value for a `key=value` rabbitmqadmin argument, so payloads/names with spaces survive
-- the one shell hop `container:exec` makes (`sh -c "<cmd>"`). Escapes embedded single quotes.
function helpers.shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Extract the `payload` column from a `rabbitmqadmin ... -f tsv` block (header row + data rows),
-- locating the column by header name so it survives column-order changes.
function helpers.parse_payloads(tsv)
  local lines = {}
  for line in tsv:gmatch("[^\n]+") do lines[#lines + 1] = line end
  if #lines < 2 then return {} end          -- header only → no messages

  local header = {}
  local idx = 0
  for col in (lines[1] .. "\t"):gmatch("([^\t]*)\t") do
    idx = idx + 1
    header[col] = idx
  end
  local payload_col = header["payload"]
  if not payload_col then error("rabbitmqadmin get: no `payload` column in output") end

  local payloads = {}
  for i = 2, #lines do
    local fields = {}
    local n = 0
    for field in (lines[i] .. "\t"):gmatch("([^\t]*)\t") do
      n = n + 1
      fields[n] = field
    end
    payloads[#payloads + 1] = fields[payload_col] or ""
  end
  return payloads
end

return helpers
