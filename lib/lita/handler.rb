module Lita
  class Handler
    extend Forwardable

    attr_reader :message, :redis
    private :redis

    def_delegators :@message, :args, :command?, :scan

    class Route < Struct.new(:pattern, :method_name, :command)
      alias_method :command?, :command
    end

    class << self
      def route(pattern, to: nil, command: false)
        @routes ||= []
        @routes << Route.new(pattern, to, command)
      end

      def dispatch(robot, message)
        instance = new(robot, message)

        @routes.each do |route|
          if route_applies?(route, instance)
            instance.public_send(
              route[:method_name],
              matches_for_route(route, instance)
            )
          end
        end
      end

      private

      def route_applies?(route, instance)
        if route.pattern === instance.message
          if route.command?
            return instance.command?
          else
            return true
          end
        end

        false
      end

      def matches_for_route(route, instance)
        instance.scan(route.pattern)
      end
    end

    def initialize(robot, message)
      @robot = robot
      @message = message
      @redis = Redis::Namespace.new(redis_namespace, redis: Lita.redis)
    end

    def say(*strings)
      @robot.say(message, *strings)
    end

    private

    def redis_namespace
      name = self.class.name.split("::").last.downcase
      "handlers:#{name}"
    end
  end
end
