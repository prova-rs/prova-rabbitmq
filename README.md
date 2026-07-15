# prova-rabbitmq

A [RabbitMQ](https://www.rabbitmq.com/) resource plugin for [Prova](https://github.com/prova-rs/prova).

Prova bundles no native AMQP client — this plugin adds the whole technology with **zero native
code**. It provisions an ephemeral RabbitMQ container and drives it through `rabbitmqadmin` *inside*
the container (a docker-exec client), so there's nothing to compile and it runs anywhere Docker
does. It's authored entirely through Prova's `prova.containerized` helper, so it comes out the
standard `{ client, url, container }` shape — the same grammar the first-party resources follow.

## Use it

Declare the plugin in your `prova.toml`:

```toml
[plugins]
rabbitmq = "prova-rs/prova-rabbitmq@v1"   # org/repo shorthand (fetched + pinned + cached)
```

Then in a test:

```lua
local rabbitmq = require("rabbitmq")

local mq = prova.fixture("rabbitmq", Scope.File, function(ctx)
  return rabbitmq.container(ctx)            -- provisions, waits, attaches a client, ties teardown
end)

prova.group("orders", { requires = { "docker" } }, function(g)
  g:test("an order is enqueued", function(t)
    local r = t:use(mq)
    r.client:declare_queue("orders")
    r.client:publish("orders", "order-42")
    t:expect(r.client:get("orders")[1]):equals("order-42")
  end)
end)
```

The typical shape is to hand `r.url` (an `amqp://…` endpoint) to the app under test via its env, let
the app produce/consume, and assert the effect either through the app's API (black-box) or directly
with the client here.

## API

`rabbitmq.container(ctx, opts?)` → `{ client, url, container }`

- `url` — `amqp://guest:guest@127.0.0.1:<port>`, the endpoint for the app under test.
- `container` — the Docker handle (`:host_port`, `:exec`, `:logs`, …).
- `client` — the docker-exec client:
  - `client:declare_queue(name, { durable? })`
  - `client:publish(queue, payload, { exchange?, routing_key? })`
  - `client:get(queue, { count?, ack? })` → list of payload strings
  - `client:list_queues()` → list of queue names

`opts`: `image`, `tag` (default `3-management`), `timeout` (default `90s`) — the `prova.containerized`
options.

## Requirements

Docker at test time. Gate tests with `requires = { "docker" }` so they skip cleanly where the daemon
is absent (CI without Docker, a locked-down laptop).

## Develop

This repo self-tests through Prova (dogfooding): `prova.toml` declares the plugin as a local path and
runs `tests/`.

```bash
prova              # runs tests/ against ./rabbitmq.lua (needs Docker)
prova plugin lint rabbitmq.lua
```

MIT licensed.
