#!/usr/bin/env ruby

require 'lib/json_rabbit'

BROKER_URL=     'http://localhost:55672/rpc'
BROKER_USERNAME='guest'
BROKER_PASSWORD='guest'
EXCHANGE=       'testapp'
QUEUE=          'logging'
ROUTING_KEY=    'routingKey'

rpc=RabbitMQ::JsonRPC.new(BROKER_URL,BROKER_USERNAME,BROKER_PASSWORD)
rpc.exchange_declare(EXCHANGE,'fanout',auto_delete=true)
rpc.basic_publish(EXCHANGE,json,routing_key=ROUTING_KEY)

# qtag=rpc.queue_declare(QUEUE)
# rpc.bind_queue(qtag,EXCHANGE)
# puts rpc.poll()

rpc.close
