
What's this?
============
A simple client library to access a RabbitMQ messaging server 
via simple HTTP request instead of using the default RabbitMQ 
protocol. The benefits are obvious: You don't have to route 
yet another protocol through firewall but instead rely on the
proven HTTP enviroment.


Current State
=============
Everything needed to publish basic messages to an exchange is 
implemented. There's support for receiving messages though it
is not yet functional.


Prerequisites
=============
You need a running [RabbitMQ message broker](http://www.rabbitmq.com/install.html) 
with the [rabbitmq-jsonrpc-channel plugin](http://www.rabbitmq.com/download.html) 
enabled. 

