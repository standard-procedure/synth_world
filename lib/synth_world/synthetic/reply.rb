# frozen_string_literal: true

require "ruby_llm"
require "json"

module SynthWorld
  class Synthetic::Reply < Literal::Data
    prop :message, SynthWorld::Synthetic::Message
    prop :response, RubyLLM::Message
    prop :time, Time, default: -> { Time.now }
    prop :headers, _Hash(Symbol, _Any), default: {}.freeze, reader: false

    def contents = @response.content
    def headers = @headers.merge(replying_to: @message.headers[:from], tokens: deconstruct_tokens)

    def to_h = {contents: contents, time: @message.time.iso8601, headers: headers}

    def to_json(*args) = to_h.to_json(*args)

    def deconstruct_tokens
      return {}.freeze unless @response.tokens
      {input: @response.tokens.input, output: @response.tokens.output, cached: @response.tokens.cached, thinking: @response.tokens.thinking}.freeze
    end
  end
end
