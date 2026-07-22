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

-- Run `rabbitmqadmin` inside the container (argv form → no shell, no quoting) and return stdout,
-- raising on a non-zero exit (so a readiness probe can retry until the management API answers).
local function admin(container, args)
  local argv = { "rabbitmqadmin" }
  for _, a in ipairs(args) do argv[#argv + 1] = a end
  return container:run(argv)
end

-- The docker-exec client: a table of methods closing over the container. No native driver, no socket,
-- no hand-rolled plumbing — quoting and TSV parsing come from the prova exec-CLI SDK.
local function make_client(container)
  local client = {}

  function client:declare_queue(name, opts)
    opts = opts or {}
    admin(container, { "declare", "queue", "name=" .. name, "durable=" .. (opts.durable and "true" or "false") })
    return self
  end

  -- Publish with routing_key = queue so the message lands in that queue. Omit `exchange` entirely
  -- to use the default (nameless) exchange — rabbitmqadmin rejects an explicit empty `exchange=`.
  function client:publish(queue, payload, opts)
    opts = opts or {}
    local args = { "publish", "routing_key=" .. (opts.routing_key or queue), "payload=" .. payload }
    if opts.exchange and opts.exchange ~= "" then
      table.insert(args, 2, "exchange=" .. opts.exchange)
    end
    admin(container, args)
    return self
  end

  -- Get up to `count` (default 1) messages from `queue`, removing them (ack). Returns their payloads
  -- as a list of strings — `prova.parse.table` reads rabbitmqadmin's TSV, keyed by header name.
  function client:get(queue, opts)
    opts = opts or {}
    local ackmode = opts.ack == false and "reject_requeue_true" or "ack_requeue_false"
    local out = admin(container, {
      "get", "queue=" .. queue, "count=" .. tostring(opts.count or 1), "ackmode=" .. ackmode, "-f", "tsv",
    })
    local payloads = {}
    for _, row in ipairs(prova.parse.table(out)) do payloads[#payloads + 1] = row.payload end
    return payloads
  end

  -- List queue names (also the readiness probe: raises until the management API is up).
  function client:list_queues()
    local names = {}
    for _, row in ipairs(prova.parse.table(admin(container, { "list", "queues", "name", "-f", "tsv" }))) do
      names[#names + 1] = row.name
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
