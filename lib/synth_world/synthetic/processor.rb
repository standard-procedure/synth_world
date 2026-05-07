# frozen_string_literal: true

module SynthWorld
  # Transient actors - base class
  #
  # `action` - defines a method that can be called from outside the processor which will execute asynchronously within the processor
  # `every` - triggers a timer every `interval` seconds that executes within the processor
  class Synthetic::Processor < Literal::Data
    prop :synthetic, SynthWorld::Synthetic
    prop :rule, String, default: ""
    prop :queue, Async::Queue, default: -> { Async::Queue.new }

    def call
      Async(transient: true) do
        start_timers
        loop do
          action, args = @queue.pop
          instance_exec(*args, &action)
        end
      end
    end
    alias_method :start, :call

    def self.action action, &implementation
      define_method action.to_sym do |*args|
        @queue.push [implementation, args]
      end
    end

    def self.every interval, &timer
      timers << [interval, timer]
    end

    def self.timers
      @timers ||= []
    end

    action :process_incoming do |message|
      Literal.check message, Synthetic::Message
      _process_incoming message
    end

    def _process_incoming message
    end

    action :process_outgoing do |reply|
      Literal.check reply, Synthetic::Reply
      _process_outgoing reply
    end

    def _process_outgoing reply
    end

    def start_timers
      self.class.timers.each do |(interval, timer)|
        start_timer interval, timer
      end
    end

    def start_timer interval, timer
      Async(transient: true) do
        loop do
          sleep interval
          @queue.push [timer, []]
        end
      end
    end
  end
end
