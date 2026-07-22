-- Self-test for prova-rabbitmq: provision RabbitMQ, then declare/publish/get a real round-trip
-- through the docker-exec client. Requires docker; skips gracefully otherwise.

local mq = prova.fixture("rabbitmq", Scope.File, function(ctx)
  return require("rabbitmq").container(ctx)
end)

prova.group("rabbitmq", { requires = { "docker" } }, function(g)
  g:test("declare, publish, and get round-trips a message", function(t)
    local r = t:use(mq)
    r.client:declare_queue("orders")
    r.client:publish("orders", "hello")
    r.client:publish("orders", "world")

    local msgs = r.client:get("orders", { count = 2 })
    t:expect(#msgs):equals(2)
    t:expect(msgs[1]):equals("hello")
    t:expect(msgs[2]):equals("world")
  end)

  g:test("url is the AMQP endpoint for the app under test", function(t)
    local r = t:use(mq)
    t:expect(r.url):matches("^amqp://")
  end)
end)
