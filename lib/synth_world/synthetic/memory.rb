# frozen_string_literal: true

require "fileutils"

module SynthWorld
  class Synthetic::Memory < Synthetic::Processor
    prop :workspace, String

    def _process_incoming(message)
      _write_to_working_memory(message.contents, message.time, **message.headers)
    end

    def _process_outgoing(reply)
      _write_to_working_memory(reply.contents, reply.time, **reply.headers)
    end

    # Synchronous read — bypasses the actor queue. Filesystem handles
    # concurrency; we'll move this to an async callback once it matters.
    def working_memory
      path = "#{workspace}/working.md"
      File.exist?(path) ? File.read(path) : ""
    end

    def _write_to_working_memory(contents, time = Time.now, **metadata)
      FileUtils.mkdir_p(workspace)
      metadata_text = metadata.collect { |key, value| "#{key}: #{value}" }.join(", ")
      memory = <<~MEMORY
        - #{time.utc.iso8601}: #{metadata_text}
          #{contents}
      MEMORY
      File.write("#{workspace}/working.md", memory, mode: "a+")
    end
  end
end
