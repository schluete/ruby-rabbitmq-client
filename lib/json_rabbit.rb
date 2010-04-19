
require 'cgi'
require 'uri'
require 'net/http'
require 'net/https'
require 'rubygems'
require 'active_support'
require 'json'

# usage:
# 
# rpc=RabbitMQ::JsonRPC.new(HULOG_BROKER_URL,HULOG_USERNAME,HULOG_PASSWORD)
# rpc.exchange_declare(HULOG_EXCHANGE,'fanout',auto_delete=true)
# rpc.basic_publish(HULOG_EXCHANGE,json,routing_key='CuRM')
#
# qtag=rpc.queue_declare('')
# rpc.bind_queue(qtag,HULOG_EXCHANGE)
# rpc.poll()
#
# rpc.close

module RabbitMQ

  class RabbitMQException < Exception 
  end

  class JsonRPC
    def initialize(url,username,password,virtual_host=nil)
      @conn=Connection.new(url)
      @conn.open(username,password,virtual_host=virtual_host)
    end

    def close()
      @conn.close()
    end

    def poll()
      @conn.poll
    end

    def queue_declare(qname,passive=false,durable=false,exclusive=false,auto_delete=true)
      args=[0,            # ticket
            qname,        # queue name
            passive,      # passive?
            durable,      # durable?
            exclusive,    # exclusive?
            auto_delete,  # auto_delete?
            false,        # no wait
            {}]           # other arguments
      result=@conn.call('queue.declare',args)
      valid_response?(result,'queue.declare',"unable to declare queue #{qname}!")
      return tag=result['args'][0]
    end

    def exchange_declare(exchange,type,passive=false,durable=false,auto_delete=false)
      args=[0,        # ticket
            exchange, # exchange
            type,     # direct, fanout etc.
            false,    # passive?
            false,    # durable?
            false,    # auto_delete?
            false,    # internal
            false,    # no wait
            {}]       # other arguments
      result=@conn.call('exchange.declare',args)
      valid_response?(result,'exchange.declare',"unable to declare exchange #{exchange}!")
    end

    def bind_queue(queue_tag,exchange,routing_key='')
      args=[0,            # ticket
            queue_tag,    # which queue?
            exchange,     # which exchange?
            routing_key,  # routing key
            false,        # nowait
            {}]           # other arguments
      result=@conn.call('queue.bind',args)
      valid_response?(result,'queue.bind',"unable to bind queue #{queue_tag} to exchange #{exchange}!")
    end

#    {"version":"1.1","id":5,"method":"call","params":["exchange.declare",[0,"rabbit","fanout",false,false,false,false,false,{}]]}
#    --> {"version":"1.1","id":5,"result":{"method":"exchange.declare_ok","args":[]}}

#    {"version":"1.1","id":6,"method":"call","params":["queue.declare",[0,"",false,false,false,true,false,{}]]}
#    --> {"version":"1.1","id":6,"result":{"method":"queue.declare_ok","args":["amq.gen-WK7i+htez3YwnWQfO6I4tA==",0,0]}}

#    {"version":"1.1","id":7,"method":"call","params":["queue.bind",[0,"amq.gen-O4dQHHkoTsLuCfCBSj0Akw==","rabbit","",false,{}]]}
#    --> {"version":"1.1","id":7,"result":{"method":"queue.bind_ok","args":[]}}
#    {"version":"1.1","id":8,"method":"call","params":["basic.consume",[0,"amq.gen-O4dQHHkoTsLuCfCBSj0Akw==","",false,true,false,false]]}
#    --> {"version":"1.1","id":8,"result":{"method":"basic.consume_ok","args":["amq.ctag-xMUd+1iPBfePJtcKUPS09A=="]}}
#    {"version":"1.1","id":9,"method":"cast","params":["basic.publish",[0,"rabbit","user4375570469",false,false],"foobar",["text/plain",null,null,null,null,null,null,null,null,null,null,null,null,null]]}
#    --> {"version":"1.1","id":9,"result":[]}
    
    def basic_consume(queue_tag,consumer_tag='',no_ack=true,no_local=false,exclusive=false)
      args=[0,            # ticket
            queue_tag,    # which queue?
            consumer_tag, # which consumer?
            no_local,     # local?
            no_ack,       # do we need an acknowledge?
            exclusive,    # exclusive?
            false]        # no wait
      result=@conn.call('basic.consume',args)
      valid_response?(result,'basic.consume',"unable to start consuming from queue #{queue_tag}!")
      return ctag=result['args'][0]
    end

    def basic_publish(exchange,message,routing_key='',content_type='text/plain',mandatory=false,immediate=false)
      args=[0,            # ticket
            exchange,     # exchange
            routing_key,  # routing_key
            mandatory,    # mandatory?
            immediate]    # immediate?
      props=[content_type,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil]
      result=@conn.cast('basic.publish',args,message,props)
    end

  private 

    def valid_response?(result,method,error)
      raise RabbitMQException.new(error) unless result['method']=="#{method}_ok"
    end

  end

  class Connection
    def initialize(url)
      uri=URI.parse(url)
      @scheme=uri.scheme
      @host=uri.host
      @port=uri.port
      @path=uri.path
      reset
    end

    def open(username,password,session_timeout=5,virtual_host=nil)
      params=[username,password,session_timeout,virtual_host]
      result=request('open',params)
      @service=result['service']
    end

    def close()
      request('close')
      reset
    end

    def poll()
      result=request('poll')
      puts result.inspect
    end

    def call(method,arguments)
      request('call',[method,arguments])
    end

    def cast(method,arguments,content,props)
      params=[method,arguments,content,props]
      result=request('cast',params)
    end

    def print_system_description
      result=request('system.describe')
      puts "service name:    #{result['name']}"
      puts "service ID:      #{result['id']}"
      puts "service version: #{result['sdversion']}"
      puts "procedures:      #{result['procs'].inspect}"
    end

  private

    def reset
      @service='rabbitmq'
      @jsonrpc_id=1
      @headers={ 'User-Agent'=>'rbJsonRabbit',
                 'X-JSON-RPC-Timeout'=>'30000' }
    end

    def request(method,params=[])
      @jsonrpc_id+=1

      req=Net::HTTP::Post.new("#{@path}/#{@service}",@headers)
      req.content_type = 'application/json; charset=UTF-8'
      req.body={ :id=>      @jsonrpc_id,
                 :version=> '1.1',
                 :method=>  method,
                 :params=>  params }.to_json
      http=Net::HTTP.new(@host,@port)
      http.use_ssl=true if @scheme=='https'
      resp=http.start { |http| http.request(req) }
      case resp
      when Net::HTTPSuccess, Net::HTTPRedirection
        result=JSON.parse(resp.body)
        if result['error']
          code=result['error']['code']
          message=result['error']['message']
          raise RabbitMQException.new("unable to execute method #{method}: (#{code}) #{message}!")
        else
          return result['result']
        end
      else
        raise RabbitMQException.new("unable to execute method #{method}!")
      end
    end
  end

end
