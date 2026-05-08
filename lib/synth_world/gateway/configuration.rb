# frozen_string_literal: true

require "yaml"

module SynthWorld
  class Gateway::Configuration < Literal::Data
    DEFAULT_PROVIDERS = {
      "embedding" => {provider: :ollama, model: "nomic-embed-text"},
      "evaluation" => {provider: :ollama, model: "qwen2.5:3b"},
      "gatekeeper" => {provider: :openrouter, model: "openai/gpt-oss-120b:free"},
      "default" => {provider: :openrouter, model: "openai/gpt-oss-120b:free"}
    }.freeze

    prop :port, _Integer, default: 7000
    prop :bind, String, default: "127.0.0.1"
    prop :socket_dir, String, default: "/tmp/synth"
    prop :pid_file, String, default: "/tmp/synth/synth.pid"
    prop :log_file, String, default: "/tmp/synth/synth.log"
    prop :synthetics, _Array(Gateway::SyntheticReference), default: -> { [] }
    prop :providers, _Hash(String, Gateway::Provider), default: -> { Gateway::Configuration.build_default_providers }

    def self.from_file(path)
      data = YAML.safe_load_file(path)

      providers = build_default_providers
      (data["providers"] || {}).each do |name, pdata|
        providers[name] = Gateway::Provider.new(
          name: name,
          provider: pdata["provider"].to_sym,
          model: pdata["model"],
          api_base: pdata["api_base"]
        )
      end

      new(
        port: data["port"] || 7000,
        bind: data["bind"] || "127.0.0.1",
        socket_dir: File.expand_path(data["socket_dir"] || "/tmp/synth"),
        pid_file: File.expand_path(data["pid_file"] || "/tmp/synth/synth.pid"),
        log_file: File.expand_path(data["log_file"] || "/tmp/synth/synth.log"),
        providers: providers,
        synthetics: (data["synthetics"] || []).map { |s|
          Gateway::SyntheticReference.new(
            name: s["name"],
            config_path: File.expand_path(s["config"]),
            main_provider: s["main_provider"] || "default",
            processing_provider: s["processing_provider"] || "evaluation",
            embedding_provider: s["embedding_provider"] || "embedding",
            gatekeeper_provider: s["gatekeeper_provider"] || "gatekeeper"
          )
        }
      )
    end

    def self.build_default_providers
      DEFAULT_PROVIDERS.each_with_object({}) do |(name, attrs), hash|
        hash[name] = Gateway::Provider.new(name: name, **attrs)
      end
    end
  end
end
