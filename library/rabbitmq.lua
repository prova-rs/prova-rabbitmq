---@meta rabbitmq
--- prova-rabbitmq — RabbitMQ resource for Prova: docker-exec over rabbitmqadmin, zero native code.
---
--- Editor-only type stub for `require("rabbitmq")`: it gives consumers completion and signatures and
--- ships nothing at runtime. Keep it in sync with init.lua's public API.

local rabbitmq = {}

--- Options for `Client:declare_queue`.
---@class rabbitmq.DeclareOpts
---@field durable? boolean  # survive a broker restart (default false)

--- Options for `Client:publish`.
---@class rabbitmq.PublishOpts
---@field routing_key? string  # override the routing key (default: the queue name)
---@field exchange? string     # publish through a named exchange (default: the nameless default exchange)

--- Options for `Client:get`.
---@class rabbitmq.GetOpts
---@field count? integer  # maximum messages to fetch (default 1)
---@field ack? boolean    # false rejects + requeues instead of acking (default true: ack, remove)

--- The docker-exec client: each method shells `rabbitmqadmin` inside the container.
---@class rabbitmq.Client
local Client = {}

--- Declare a queue; idempotent. Returns the client for chaining.
---@param name string
---@param opts? rabbitmq.DeclareOpts
---@return rabbitmq.Client
function Client:declare_queue(name, opts) end

--- Publish `payload` so it lands in `queue` (routing_key = queue through the default exchange,
--- unless overridden). Returns the client for chaining.
---@param queue string
---@param payload string
---@param opts? rabbitmq.PublishOpts
---@return rabbitmq.Client
function Client:publish(queue, payload, opts) end

--- Get up to `opts.count` (default 1) messages from `queue`, removing them (ack). Returns their
--- payloads as a list of strings.
---@param queue string
---@param opts? rabbitmq.GetOpts
---@return string[]
function Client:get(queue, opts) end

--- List queue names. Raises until the management API is up — also the readiness probe.
---@return string[]
function Client:list_queues() end

--- No-op (present for lifecycle symmetry); the container teardown reaps everything.
function Client:close() end

--- The provisioned resource: the standard `prova.containerized` shape with the docker-exec
--- client attached.
---@class rabbitmq.Resource
---@field client rabbitmq.Client  # the attached docker-exec client
---@field url string              # host-vantage AMQP endpoint (amqp://guest:guest@127.0.0.1:port) for the app under test
---@field host string             # "127.0.0.1"
---@field port integer            # the mapped host port for AMQP (container port 5672)
---@field container any           # the docker Container handle
---@field network? any            # network vantage, present when provisioned on a topology network

--- Provision a `rabbitmq:3-management` container, wait until the management API answers, attach the
--- docker-exec client, and tie teardown to `ctx`. `opts` overrides `image`/`tag`/`timeout`/`env` as
--- with any `prova.containerized` resource. Requires docker — gate with `requires = { "docker" }`.
---@param ctx any
---@param opts? table
---@return rabbitmq.Resource
function rabbitmq.container(ctx, opts) end

--- The client factory (grammar symmetry; rarely called directly). A docker-exec client attaches to
--- the `container`, not the `url` — pass the running container handle; `url` is ignored.
---@param url string
---@param opts? table
---@param container any
---@return rabbitmq.Client
function rabbitmq.client(url, opts, container) end

return rabbitmq
