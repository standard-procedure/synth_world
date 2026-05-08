# frozen_string_literal: true

module SynthWorld
  # A message that arrived via the gateway's HTTP/Unix-socket bridge.
  # Carries a reply_to callback so the synth can route the reply back
  # through the same connection.
  class Synthetic::GatewayMessage < Synthetic::Message
    prop :reply_to, Proc

    def deliver(reply)
      @reply_to.call(reply)
    end
  end
end
