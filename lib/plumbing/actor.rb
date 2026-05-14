# frozen_string_literal: true

require_relative "actor/configuration"
require_relative "actor/definitions"
require_relative "actor/inline"

module Plumbing
  module Actor
    extend Configuration

    FIBER_KEY = :plumbing_actor_current_sender

    def initialize(...)
      super
      @worker = Plumbing::Actor.worker_for self
    end
    attr_reader :worker

    # The actor that sent the message currently being processed, or nil.
    # Set per-message by Message#deliver via a fiber-local; safe under the
    # Async worker because each delivery runs in its own Async::Task fiber.
    def current_sender = Fiber[FIBER_KEY]

    def self.included klass
      klass.extend Definitions
    end
  end
end
