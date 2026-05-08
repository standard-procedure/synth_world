# frozen_string_literal: true

require "tmpdir"

RSpec.describe SynthWorld::Gateway::Configuration do
  describe "defaults" do
    subject(:config) { described_class.new }

    it "binds to 127.0.0.1 by default" do
      expect(config.bind).to eq("127.0.0.1")
    end

    it "listens on port 7000 by default" do
      expect(config.port).to eq(7000)
    end

    it "includes the three built-in providers" do
      expect(config.providers.keys).to include("embedding", "evaluation", "default")
    end

    it "defaults embedding to ollama / nomic-embed-text" do
      p = config.providers["embedding"]
      expect(p.provider).to eq(:ollama)
      expect(p.model).to eq("nomic-embed-text")
    end

    it "defaults evaluation to ollama / qwen2.5:3b" do
      p = config.providers["evaluation"]
      expect(p.provider).to eq(:ollama)
      expect(p.model).to eq("qwen2.5:3b")
    end

    it "defaults default to openrouter / gpt-oss-120b" do
      p = config.providers["default"]
      expect(p.provider).to eq(:openrouter)
      expect(p.model).to eq("openai/gpt-oss-120b:free")
    end
  end

  describe ".from_file" do
    let(:tmpdir) { Dir.mktmpdir("synth_config_test") }
    after { FileUtils.rm_rf(tmpdir) }

    def write_config(yaml)
      path = "#{tmpdir}/gateway.yml"
      File.write(path, yaml)
      path
    end

    it "defaults bind to 127.0.0.1 when not specified" do
      path = write_config("port: 7000\n")
      expect(described_class.from_file(path).bind).to eq("127.0.0.1")
    end

    it "reads bind from the file" do
      path = write_config("port: 7000\nbind: 0.0.0.0\n")
      expect(described_class.from_file(path).bind).to eq("0.0.0.0")
    end

    it "keeps built-in provider defaults when providers section is absent" do
      path = write_config("port: 7000\n")
      config = described_class.from_file(path)
      expect(config.providers.keys).to include("embedding", "evaluation", "default")
    end

    it "overrides a built-in provider when specified in the file" do
      path = write_config(<<~YAML)
        port: 7000
        providers:
          default:
            provider: openai
            model: gpt-4o
      YAML
      p = described_class.from_file(path).providers["default"]
      expect(p.provider).to eq(:openai)
      expect(p.model).to eq("gpt-4o")
    end

    it "adds a custom provider alongside the built-ins" do
      path = write_config(<<~YAML)
        port: 7000
        providers:
          fast:
            provider: openai
            model: gpt-4o-mini
      YAML
      config = described_class.from_file(path)
      expect(config.providers.keys).to include("embedding", "evaluation", "default", "fast")
    end

    it "reads a custom api_base for a provider" do
      path = write_config(<<~YAML)
        port: 7000
        providers:
          local:
            provider: ollama
            model: llama3
            api_base: http://192.168.1.100:11434/v1
      YAML
      p = described_class.from_file(path).providers["local"]
      expect(p.api_base).to eq("http://192.168.1.100:11434/v1")
    end
  end

  describe "SyntheticReference provider defaults" do
    let(:tmpdir) { Dir.mktmpdir("synth_config_test") }
    after { FileUtils.rm_rf(tmpdir) }

    let(:synth_config) { "#{tmpdir}/cher.yml" }
    before { File.write(synth_config, "name: cher\n") }

    def write_gateway(extra = "")
      path = "#{tmpdir}/gateway.yml"
      File.write(path, <<~YAML + extra)
        port: 7000
        synthetics:
          - name: cher
            config: #{synth_config}
      YAML
      path
    end

    subject(:ref) { described_class.from_file(write_gateway).synthetics.first }

    it "defaults main_provider to 'default'" do
      expect(ref.main_provider).to eq("default")
    end

    it "defaults processing_provider to 'evaluation'" do
      expect(ref.processing_provider).to eq("evaluation")
    end

    it "defaults embedding_provider to 'embedding'" do
      expect(ref.embedding_provider).to eq("embedding")
    end

    it "reads explicit provider overrides from the gateway config" do
      path = write_gateway(<<~YAML)
        synthetics:
          - name: cher
            config: #{synth_config}
            main_provider: openai-premium
            processing_provider: fast
            embedding_provider: local-embed
      YAML
      ref = described_class.from_file(path).synthetics.first
      expect(ref.main_provider).to eq("openai-premium")
      expect(ref.processing_provider).to eq("fast")
      expect(ref.embedding_provider).to eq("local-embed")
    end
  end
end
