# frozen_string_literal: true

require "async/semaphore"
require "ruby_llm"
require "yaml"
require_relative "types"

module SynthWorld
  class Synthetic < Literal::Object
  end
end

require_relative "synthetic/message"
require_relative "synthetic/gateway_message"
require_relative "synthetic/reply"
require_relative "synthetic/gatekeeper"
require_relative "synthetic/processor"
require_relative "synthetic/memory"

module SynthWorld
  class Synthetic < Literal::Object
    extend Types

    prop :name, String
    prop :biography, String
    prop :workspace, String

    prop :rules, _Hash(Symbol, String)
    prop :processors, _Hash(Symbol, Synthetic::Processor), default: -> { default_processors }
    prop :main_context, _Nilable(RubyLLM::Context)
    prop :processing_context, _Nilable(RubyLLM::Context)
    prop :embedding_context, _Nilable(RubyLLM::Context)
    prop :state, _Hash(Symbol, _Float), default: -> { {anxiety: 0.0, arousal: 0.0, temperature: 0.7} }
    prop :status, _OneOf(:offline, :asleep, :idle, :busy), default: :offline
    prop :active, _Boolean, default: true
    prop :concurrency_limit, _Integer, default: 8
    prop :queue, Async::Queue, default: -> { Async::Queue.new }
    prop :semaphore, Async::Semaphore, default: -> { Async::Semaphore.new(@concurrency_limit) }
    prop :gatekeeper, SynthWorld::Synthetic::Gatekeeper, default: -> { SynthWorld::Synthetic::Gatekeeper.new(synthetic: self, input_rule: @rules[:gatekeeper_input_rule], output_rule: @rules[:gatekeeper_output_rule]) }

    def self.from_file(path, main_context: nil, processing_context: nil, embedding_context: nil)
      data = YAML.safe_load_file(path)
      rules = (data["rules"] || {}).transform_keys(&:to_sym)
      new(
        name: data.fetch("name"),
        biography: data["biography"] || "",
        workspace: File.expand_path(data.fetch("workspace")),
        rules: rules,
        processors: {},
        main_context: main_context,
        processing_context: processing_context,
        embedding_context: embedding_context
      )
    end

    def start
      start_processors
      start_main_loop
    end
    alias_method :call, :start

    def stop
      @active = false
      @queue.close
    end

    # Push a message onto the consumption queue. Wakes the main loop.
    def dispatch(message)
      @queue.push message
    end

    private def start_main_loop
      @status = :idle
      @queue.async(parent: @semaphore) { |_task, message| process(message) }
    ensure
      @status = :offline
    end

    private def start_processors
      @processors.each_value(&:start)
    end

    private def process message
      Literal.check message, Synthetic::Message
      @gatekeeper.assess incoming: message
      @processors.each { |_, p| p.process_incoming message }
      reply = reply_to message
      @gatekeeper.evaluate outgoing: reply
      @processors.each { |_, p| p.process_outgoing reply }
      output reply
    end

    def reply_to message
      response = @main_context.chat
        .with_instructions(generate_system_prompt)
        .with_tools(generate_tools)
        .with_temperature(@state[:temperature])
        .ask(generate_prompt_for(message), with: message.attachment)
      Synthetic::Reply.new message: message, response: response
    end

    def generate_system_prompt
      <<~PROMPT
        #{@rules[:operating_system]}
        Other stuff
      PROMPT
    end

    def generate_tools
      []
    end

    def generate_message_history
      # TODO: read working memory from workspace
      ""
    end

    def generate_prompt_for message
      <<~PROMPT
        #{generate_message_history}
        Other stuff
        #{message.contents}
      PROMPT
    end

    # Delegate delivery to the originating message — different message
    # subclasses know how to route replies back to their channel.
    def output(reply)
      reply.message.deliver(reply)
    end

    def default_processors
      {
        memory: SynthWorld::Synthetic::Memory.new(synthetic: self, workspace: "#{@workspace}/memory")
      }
    end
  end
end
