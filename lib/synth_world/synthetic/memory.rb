# # frozen_string_literal: true

module SynthWorld
  class Synthetic::Memory < Synthetic::Processor
    prop :workspace, String

    def _process_incoming message
      File.write "#{workspace}/working.md", message.to_memory, mode: "a+"
    end

    def _process_outgoing reply
      File.write "#{workspace}/working.md", reply.to_memory, mode: "a+"
    end
  end
end
