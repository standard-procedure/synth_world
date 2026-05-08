# frozen_string_literal: true

require "ruby_llm"
module SynthWorld
  class Synthetic::Reply < Literal::Data
    prop :message, SynthWorld::Synthetic::Message
    prop :response, RubyLLM::Message
    prop :time, Time, default: -> { Time.now }
    prop :headers, _Hash(Symbol, _Any), default: {}.freeze

    def contents = @response.content
  end
end
