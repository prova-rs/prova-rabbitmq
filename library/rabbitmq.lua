---@meta rabbitmq
--- LuaCATS annotations for the `rabbitmq` Prova plugin — the consumer-facing contract for
--- `local rabbitmq = require("rabbitmq")`. prova syncs this into a project's `annotations/` so
--- `require("rabbitmq")` resolves by module name. Keep in step with `../rabbitmq.lua`.

---A docker-exec RabbitMQ client (drives `rabbitmqadmin` inside the container).
---@class rabbitmq.Client
local Client = {}

---Declare a queue (idempotent).
---@param name string
---@param opts { durable?: boolean }?
---@return rabbitmq.Client self
function Client:declare_queue(name, opts) end

---Publish a payload to a queue (routing_key defaults to the queue name; omit `exchange` for default).
---@param queue string
---@param payload string
---@param opts { routing_key?: string, exchange?: string }?
---@return rabbitmq.Client self
function Client:publish(queue, payload, opts) end

---Get up to `count` (default 1) messages from a queue, acking by default. Returns their payloads.
---@param queue string
---@param opts { count?: integer, ack?: boolean }?
---@return string[] payloads
function Client:get(queue, opts) end

---@return string[] queue names
function Client:list_queues() end

---No-op; the container teardown reaps everything.
function Client:close() end

---The provisioned RabbitMQ: `{ client, url, container }`.
---@class rabbitmq.Resource
---@field client rabbitmq.Client the client to drive RabbitMQ
---@field url string the `amqp://…` endpoint for the app under test
---@field container prova.Container the raw container (host_port, logs, run, exec, stop)

---@class rabbitmq
local rabbitmq = {}

---Provision an ephemeral RabbitMQ broker and return the resource. Teardown is tied to `ctx`.
---@param ctx prova.Context
---@param opts table? image/tag/port overrides
---@return rabbitmq.Resource
function rabbitmq.container(ctx, opts) end

return rabbitmq
