# frozen_string_literal: true

require "fileutils"

module SynthWorld
  class Synthetic::Memory < Synthetic::Processor
    SUMMARISE_PROMPT = <<~SUMMARISE_PROMPT
      Create a single paragraph summary of this information:

      {{ synth_working_memory }}
    SUMMARISE_PROMPT

    prop :workspace, String

    every 60 do
      _summarise_working_memory
    end

    def _process_incoming(message, **metadata)
      _write_to_working_memory(message.contents, message.time, **message.headers.merge(metadata))
    end

    def _process_outgoing(reply, **metadata)
      _write_to_working_memory(reply.contents, reply.time, **reply.headers.merge(metadata))
    end

    # Synchronous read — bypasses the actor queue. Filesystem handles
    # concurrency; we'll move this to an async callback once it matters.
    def working_memory
      path = "#{@workspace}/working.md"
      File.exist?(path) ? File.read(path) : ""
    end

    def working_summary
      path = "#{@workspace}/working-summary.md"
      File.exist?(path) ? File.read(path) : ""
    end

    def _write_to_working_memory(contents, time = Time.now, **metadata)
      FileUtils.mkdir_p(@workspace)
      metadata_text = metadata.collect { |key, value| "#{key}: #{value}" }.join(", ")
      memory = <<~MEMORY
        - #{time.utc.iso8601}: #{metadata_text}
          #{contents}
      MEMORY
      File.write("#{@workspace}/working.md", memory, mode: "a+")
    end

    def _summarise_working_memory
      FileUtils.mkdir_p(@workspace)
      prompt = SUMMARISE_PROMPT.gsub("{{ synth_working_memory }}", working_memory)
      ctx = @synthetic.processing_context
      provider = @synthetic.processing_provider
      chat = provider ? ctx.chat(provider: provider, assume_model_exists: true) : ctx.chat
      response = chat.ask(prompt)
      File.write("#{@workspace}/working-summary.md", response.content, mode: "w+")
    end
  end
end
