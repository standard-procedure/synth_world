# frozen_string_literal: true

RSpec.describe SynthWorld::Gateway do
  let(:config) do
    SynthWorld::Gateway::Configuration.new(
      providers: {
        "default" => SynthWorld::Gateway::Provider.new(name: "default", provider: :ollama, model: "llama3"),
        "evaluation" => SynthWorld::Gateway::Provider.new(name: "evaluation", provider: :ollama, model: "qwen2.5:3b"),
        "embedding" => SynthWorld::Gateway::Provider.new(name: "embedding", provider: :ollama, model: "nomic-embed-text")
      }
    )
  end

  let(:ref) do
    SynthWorld::Gateway::SyntheticReference.new(
      name: "cher",
      config_path: "/tmp/cher.yml"
    )
  end

  subject(:gateway) { described_class.new(config: config) }

  describe "#contexts_for" do
    it "returns a context for each role using the synthetic's provider names" do
      contexts = gateway.send(:contexts_for, ref)
      expect(contexts.keys).to contain_exactly(:main, :processing, :embedding)
      expect(contexts.values).to all(be_a(RubyLLM::Context))
    end

    it "uses the model from the named provider for each role" do
      contexts = gateway.send(:contexts_for, ref)
      expect(contexts[:main].config.default_model).to eq("llama3")
      expect(contexts[:processing].config.default_model).to eq("qwen2.5:3b")
      expect(contexts[:embedding].config.default_model).to eq("nomic-embed-text")
    end

    it "honours explicit provider overrides on the synthetic" do
      override = SynthWorld::Gateway::SyntheticReference.new(
        name: "cher", config_path: "/tmp/cher.yml",
        main_provider: "embedding"  # use the embedding provider for main
      )
      contexts = gateway.send(:contexts_for, override)
      expect(contexts[:main].config.default_model).to eq("nomic-embed-text")
    end

    it "raises a KeyError when a provider name is unknown" do
      bad_ref = SynthWorld::Gateway::SyntheticReference.new(
        name: "cher", config_path: "/tmp/cher.yml",
        main_provider: "nonexistent"
      )
      expect { gateway.send(:contexts_for, bad_ref) }.to raise_error(KeyError)
    end
  end
end
