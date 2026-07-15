-- prova-rabbitmq — a RabbitMQ resource plugin for Prova, authored the same way first-party recipes
-- are: one namespace table following the grammar, composing primitives, `return`ed. Prova bundles no
-- native AMQP client, so this proves a plugin can add a whole technology with **zero native code** —
-- the client is a docker-exec wrapper over `rabbitmqadmin` inside the container (strategy B from the
-- ecosystem design), and `prova.containerized` supplies provisioning, readiness, and lifecycle.
--
--   local rabbitmq = require("rabbitmq")
--   local mq = rabbitmq.container(ctx)          -- { client, url, container }
--   mq.client:declare_queue("orders")
--   mq.client:publish("orders", "hello")
--   local msgs = mq.client:get("orders")        -- { "hello" }
--
-- The container image is `rabbitmq:3-management` (ships `rabbitmqadmin`); `url` is the AMQP endpoint
-- to hand the app under test. Requires docker at call time — gate tests with requires = { "docker" }.

-- Run `rabbitmqadmin` inside the container. Returns stdout; raises on a non-zero exit (so a readiness
-- probe can retry until the management API answers). `args` are already-safe token strings.
local function admin(container, args)
  local cmd = "rabbitmqadmin " .. table.concat(args, " ")
  local code, out, err = container:exec(cmd)
  if code ~= 0 then
    error("rabbitmqadmin " .. table.concat(args, " ") .. " failed (" .. code .. "): " .. (err ~= "" and err or out))
  end
  return out
end

-- Quote a value for a `key=value` rabbitmqadmin argument, so payloads/names with spaces survive the
-- one shell hop `container:exec` makes (`sh -c "<cmd>"`). Single-quote and escape embedded quotes.
local function q(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Extract the `payload` column from a `rabbitmqadmin ... -f tsv` block (header row + data rows).
local function parse_payloads(tsv)
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

-- The docker-exec client: a table of methods closing over the container. No native driver, no socket.
local function make_client(container)
  local client = {}

  function client:declare_queue(name, opts)
    opts = opts or {}
    local durable = opts.durable and "true" or "false"
    admin(container, { "declare", "queue", "name=" .. q(name), "durable=" .. durable })
    return self
  end

  -- Publish with routing_key = queue so the message lands in that queue. Omit `exchange` entirely
  -- to use the default (nameless) exchange — rabbitmqadmin rejects an explicit empty `exchange=`.
  function client:publish(queue, payload, opts)
    opts = opts or {}
    local routing_key = opts.routing_key or queue
    local args = { "publish", "routing_key=" .. q(routing_key), "payload=" .. q(payload) }
    if opts.exchange and opts.exchange ~= "" then
      table.insert(args, 2, "exchange=" .. q(opts.exchange))
    end
    admin(container, args)
    return self
  end

  -- Get up to `count` (default 1) messages from `queue`, removing them (ack). Returns their payloads
  -- as a list of strings. Parses `rabbitmqadmin`'s TSV, locating the `payload` column by header name.
  function client:get(queue, opts)
    opts = opts or {}
    local count = opts.count or 1
    local ackmode = opts.ack == false and "reject_requeue_true" or "ack_requeue_false"
    local out = admin(container, {
      "get", "queue=" .. q(queue), "count=" .. tostring(count), "ackmode=" .. ackmode, "-f", "tsv",
    })
    return parse_payloads(out)
  end

  -- List queue names (also the readiness probe: raises until the management API is up).
  function client:list_queues()
    local out = admin(container, { "list", "queues", "name", "-f", "tsv" })
    local names = {}
    local first = true
    for line in out:gmatch("[^\n]+") do
      if first then first = false            -- skip the header row
      elseif line ~= "" then names[#names + 1] = line end
    end
    return names
  end

  -- Present for ctx:manage symmetry; the container teardown reaps everything, so this is a no-op.
  function client:close() end

  return client
end

-- The namespace: `container` provisions + waits + attaches a docker-exec client; `client` is the
-- factory (rarely used directly for exec clients, but present for grammar symmetry). Built through
-- prova.containerized, so it comes out the standard `{ client, url, container }` shape.
local rabbitmq = prova.containerized{
  name = "rabbitmq",
  image = "rabbitmq", tag = "3-management",
  ports = { 5672, 15672 },  -- 5672 AMQP (readiness + url), 15672 management (rabbitmqadmin target)
  port = 5672,
  timeout = "90s",
  url = function(host_port)
    return "amqp://guest:guest@127.0.0.1:" .. host_port
  end,
  -- The factory ignores `url`; it execs into the container. Its list_queues() call is the real
  -- readiness gate — it raises until the management API answers, and prova.retry loops until it holds.
  client = function(_url, _opts, container)
    local client = make_client(container)
    client:list_queues()
    return client
  end,
}

return rabbitmq
