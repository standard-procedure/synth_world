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

  describe "#handle_connection" do
    let(:tmpdir) { Dir.mktmpdir("gateway_handle_test") }
    after { FileUtils.rm_rf(tmpdir) }

    let(:synth) do
      SynthWorld::Synthetic.new(
        name: "test", biography: "test", workspace: tmpdir,
        rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: ""},
        processors: {}
      )
    end

    let(:conn) do
      instance_double(UNIXSocket).tap do |c|
        allow(c).to receive(:read).and_return('{"contents":"hi","headers":{"from":"baz"}}')
        allow(c).to receive(:write)
        allow(c).to receive(:close_write)
      end
    end

    before { allow(synth).to receive(:dispatch) }

    it "dispatches a GatewayMessage onto the synth" do
      gateway.send(:handle_connection, synth, conn)
      expect(synth).to have_received(:dispatch).with(
        an_instance_of(SynthWorld::Synthetic::GatewayMessage)
      )
    end

    it "passes through contents and symbol-keyed headers" do
      dispatched = nil
      allow(synth).to receive(:dispatch) { |msg| dispatched = msg }
      gateway.send(:handle_connection, synth, conn)
      expect(dispatched.contents).to eq("hi")
      expect(dispatched.headers).to eq({from: "baz"})
    end

    it "writes the reply JSON when reply_to is invoked" do
      dispatched = nil
      allow(synth).to receive(:dispatch) { |msg| dispatched = msg }
      gateway.send(:handle_connection, synth, conn)

      llm = RubyLLM::Message.new(role: :assistant, content: "Hi back!")
      reply = SynthWorld::Synthetic::Reply.new(message: dispatched, response: llm)
      dispatched.reply_to.call(reply)

      expect(conn).to have_received(:write).with(reply.to_json)
      expect(conn).to have_received(:close_write)
    end

    it "writes a JSON error to the connection on parse failure" do
      allow(conn).to receive(:read).and_return("not json")
      gateway.send(:handle_connection, synth, conn)
      expect(conn).to have_received(:write).with(/error/)
    end
  end
end
