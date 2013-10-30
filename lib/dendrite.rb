require 'chef/application/solo'
require 'chef/config'
require 'zk'
require 'pp'

class Chef
  class Config
    zk_hosts [ 'localhost:2181' ]
    services { }
    nginx_config  "/etc/nginx/nginx.conf"
    nginx_reload  "/etc/init.d/nginx reload"
    nginx_restart "/etc/init.d/nginx restart"
    nginx_stop    "/etc/init.d/nginx stop"
    nginx_start   "/etc/init.d/nginx start"
    nginx_status  "/etc/init.d/nginx status"
    attributes {}
  end
end

module Dendrite
  class Application < Chef::Application::Solo
    self.options = Chef::Application::Solo.options
    self.banner Chef::Application::Solo.banner

    SELF_PIPE = []

    def reconfigure!
      @config_updated = true
    end
    
    def run_application
      Chef::Config[:interval] ||= 1800

      SELF_PIPE.replace IO.pipe
      Chef::Config[:cookbook_path].unshift(File.expand_path('../dendrite/cookbooks', __FILE__))

      @chef_client_json = Chef::Config[:attributes] || {}
      @chef_client_json['services'] = {}
      @chef_client_json['run_list'] = ['recipe[dendrite]']

      @config_updated = true

      #Chef::Daemon.daemonize("dendrite")

      @zk = ZK.new(Chef::Config[:zk_hosts].shuffle.join(','))

      @watchers = []
      Chef::Config[:services].each do |k,v|
        v["default_servers"] ||= []
        v["rise"] ||= 3
        v["fall"] ||=  2
        v["keepalives"] ||= 64
        v["uri"] ||= "/"
        v["timeout"] ||= 1
        v["server_names"] ||= [ k ]
        v["interval"] ||= 5

        w = Watcher.new(self, k, @zk, v)
        @watchers << w
        w.watcher_callback.call
      end

      loop do
        client_sleep Chef::Config[:interval]
        begin
          run_chef_client
        rescue SystemExit => e
          raise
        rescue Exception => e
          Chef::Log.error("#{e.class}: #{e}")
          Chef::Log.error("#{e.backtrace}")
          Chef::Log.error("Sleeping for #{Chef::Config[:interval]} seconds before trying again")
          unless SELF_PIPE.empty?
            client_sleep Chef::Config[:interval]
          end
          retry
        end
      end

    end

    def run_chef_client
      @watchers.each do |w|
        @chef_client_json['services'][w.name] = Chef::Config[:services][w.name].merge('backends' => w.backends)
      end

      @chef_client = Chef::Client.new(
                                      @chef_client_json
                                      )
      @chef_client.run
      @chef_client = nil
    end

    def client_sleep(sec)
      #IO.select([ SELF_PIPE[0] ], nil, nil, sec) or return
      #SELF_PIPE[0].getc
      while sec > 0 do
        if @config_updated
          @config_updated = false
          return
        else
          sleep 5
          sec -= 5
        end
      end
    end

    class Watcher
      attr_reader :backends
      attr_reader :name
      def initialize(app, name, zk, opts)
        @app = app
        @zk = zk
        @opts = opts
        @name = name
        @backends = opts['default_servers'] || []
      end

      def watcher_callback
        @callback ||= Proc.new do |event|
          watch
          discover
          @app.reconfigure!
        end
      end

      def watch
        @watcher.unsubscribe if defined? @watcher
        @watcher = @zk.register(@opts['path'], &watcher_callback)
      end

      # tries to extract host/port from a json hash
      def parse_json(data)
        begin
          json = JSON.parse data
        rescue Object => o
          return false
        end
        raise 'instance json data does not have host key' unless json.has_key?('host')
        raise 'instance json data does not have port key' unless json.has_key?('port')
        return json['host'], json['port']
      end

      # decode the data at a zookeeper endpoint
      def deserialize_service_instance(data)
        # if that does not work, try json
        host, port = parse_json(data)
        return host, port if host

        # if we got this far, then we have a problem
        raise "could not decode this data:\n#{data}"
      end

      def discover
        new_backends = []
        begin
          @zk.children(@opts['path'], :watch => true).map do |name|
            node = @zk.get("#{@opts['path']}/#{name}")
            begin
              host, port = deserialize_service_instance(node.first)
            rescue
              Chef::Log.error("dendrite: invalid data in ZK node #{name} at #{@opts['path']}")
            else
              new_backends << { 'name' => name, 'host' => host, 'port' => port}
            end
          end
        rescue ZK::Exceptions::NoNode
          # the path must exist, otherwise watch callbacks will not work
          create(@opts['path'])
          retry
        end

        unless new_backends.empty?
          @backends = new_backends
        end
      end

    end

  end

end
