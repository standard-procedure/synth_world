# frozen_string_literal: true

RSpec.describe SynthWorld::Gateway::Provider do
  describe "#context" do
    around do |example|
      original = ENV.to_h
      example.run
    ensure
      ENV.replace(original)
    end

    it "returns a RubyLLM::Context" do
      provider = described_class.new(name: "default", provider: :ollama, model: "llama3")
      expect(provider.context).to be_a(RubyLLM::Context)
    end

    it "sets the default model on the context" do
      provider = described_class.new(name: "default", provider: :ollama, model: "llama3")
      expect(provider.context.config.default_model).to eq("llama3")
    end

    it "reads the API key from the matching ENV var for cloud providers" do
      ENV["OPENROUTER_API_KEY"] = "sk-or-test-123"
      provider = described_class.new(name: "default", provider: :openrouter, model: "google/gemma-2-9b-it:free")
      expect(provider.context.config.openrouter_api_key).to eq("sk-or-test-123")
    end

    it "raises when an API key is required but the ENV var is missing" do
      ENV.delete("OPENROUTER_API_KEY")
      provider = described_class.new(name: "default", provider: :openrouter, model: "x")
      expect { provider.context }.to raise_error(KeyError)
    end

    it "does not require an API key for ollama" do
      ENV.delete("OLLAMA_API_KEY")
      provider = described_class.new(name: "embedding", provider: :ollama, model: "nomic-embed-text")
      expect { provider.context }.not_to raise_error
    end

    it "defaults ollama_api_base to localhost when not specified" do
      provider = described_class.new(name: "embedding", provider: :ollama, model: "nomic-embed-text")
      expect(provider.context.config.ollama_api_base).to eq("http://localhost:11434/v1")
    end

    it "uses an explicit api_base when provided" do
      provider = described_class.new(name: "remote", provider: :ollama, model: "llama3", api_base: "http://192.168.1.50:11434/v1")
      expect(provider.context.config.ollama_api_base).to eq("http://192.168.1.50:11434/v1")
    end
  end
end
