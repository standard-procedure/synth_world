# frozen_string_literal: true

require "ruby_llm"

module SynthWorld
  class Gateway::Provider < Literal::Data
    # ENV var to read for each provider's API key. Providers not in this map
    # (eg. ollama) don't need a key.
    API_KEY_ENV = {
      openai: "OPENAI_API_KEY",
      anthropic: "ANTHROPIC_API_KEY",
      openrouter: "OPENROUTER_API_KEY",
      deepseek: "DEEPSEEK_API_KEY",
      gemini: "GEMINI_API_KEY",
      mistral: "MISTRAL_API_KEY",
      perplexity: "PERPLEXITY_API_KEY",
      xai: "XAI_API_KEY"
    }.freeze

    OLLAMA_DEFAULT_BASE = "http://localhost:11434/v1"

    prop :name, String
    prop :provider, Symbol
    prop :model, String
    prop :api_base, _Nilable(String)

    def context
      provider_sym = @provider
      model_name = @model
      base_url = @api_base || ((provider_sym == :ollama) ? OLLAMA_DEFAULT_BASE : nil)
      env_key = API_KEY_ENV[provider_sym]

      puts "Connecting to #{@provider}:#{@model}"
      RubyLLM.context do |config|
        config.default_model = model_name
        config.public_send("#{provider_sym}_api_key=", ENV.fetch(env_key)) if env_key
        config.public_send("#{provider_sym}_api_base=", base_url) if base_url && config.respond_to?("#{provider_sym}_api_base=")
      end
    end
  end
end
