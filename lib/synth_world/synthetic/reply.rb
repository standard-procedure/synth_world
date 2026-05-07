# frozen_string_literal: true

require "ruby_llm"
module SynthWorld
  class Synthetic::Reply < Literal::Data
    prop :message, SynthWorld::Synthetic::Message
    prop :response, RubyLLM::Message
    prop :replying_to, String, default: -> { @message.from }
    prop :contents, String, default: -> { @response.content }

    def to_memory
      <<~MEMORY
        - #{@message.time.iso8601} - replying-to: #{@replying_to}
          #{@contents}
      MEMORY
    end
  end
end
