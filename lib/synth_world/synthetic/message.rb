# frozen_string_literal: true

module SynthWorld
  class Synthetic::Message < Literal::Data
    prop :contents, String
    prop :attachment, _Nilable(String)
    prop :time, Time, default: -> { Time.now }
    prop :headers, _Hash(Symbol, _Any), default: {}.freeze

    # Default delivery — for messages with no real source channel,
    # just print the reply to stdout. Subclasses override per channel.
    def deliver(reply)
      puts reply.contents
    end
  end
end
