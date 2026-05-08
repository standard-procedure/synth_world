# frozen_string_literal: true

require "json"

module SynthWorld
  # Sent back through the same channel as a Reply when the synth fails
  # to process a message — so the caller gets a response instead of
  # hanging on a dropped connection.
  class Synthetic::ErrorResponse < Literal::Data
    prop :message, SynthWorld::Synthetic::Message
    prop :error, String
    prop :time, Time, default: -> { Time.now }

    def to_h
      {error: @error, time: @time.iso8601, replying_to: @message.headers[:from]}
    end

    def to_json(*args) = to_h.to_json(*args)
  end
end
