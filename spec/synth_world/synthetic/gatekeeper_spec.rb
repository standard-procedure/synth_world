# frozen_string_literal: true

require "tmpdir"

RSpec.describe SynthWorld::Synthetic::Gatekeeper do
  let(:tmpdir) { Dir.mktmpdir("gatekeeper_test") }
  after { FileUtils.rm_rf(tmpdir) }

  let(:time) { Time.new(2026, 5, 8, 9, 0, 0) }
  let(:message) { SynthWorld::Synthetic::Message.new(contents: "hi", time: time, headers: {from: "baz"}) }
  let(:llm_response) { RubyLLM::Message.new(role: :assistant, content: "Hi!") }
  let(:reply) { SynthWorld::Synthetic::Reply.new(message: message, response: llm_response) }

  # Real RubyLLM::Context (not frozen) so we can stub `chat`.
  let(:gatekeeper_context) do
    RubyLLM.context do |c|
      c.default_model = "gpt-4o-mini"
      c.openai_api_key = "dummy"
    end
  end

  let(:chat) do
    instance_double(RubyLLM::Chat).tap do |c|
      allow(c).to receive(:ask).and_return(llm_verdict_response)
    end
  end

  let(:synth) do
    SynthWorld::Synthetic.new(
      name: "test", biography: "test", workspace: tmpdir,
      rules: {},
      processors: {},
      gatekeeper_context: gatekeeper_context
    )
  end

  before { allow(gatekeeper_context).to receive(:chat).and_return(chat) }

  subject(:gatekeeper) { described_class.new(synthetic: synth) }

  def double_response(content)
    RubyLLM::Message.new(role: :assistant, content: content)
  end

  describe "#assess" do
    context "when the model returns a clean verdict" do
      let(:llm_verdict_response) { double_response("REPLY") }

      it "returns the verdict" do
        expect(gatekeeper.assess(incoming: message)).to eq("REPLY")
      end
    end

    context "when the verdict is wrapped in markdown" do
      let(:llm_verdict_response) { double_response("**REPLY**") }

      it "still extracts the verdict" do
        expect(gatekeeper.assess(incoming: message)).to eq("REPLY")
      end
    end

    context "when the model is chatty but the verdict comes first" do
      let(:llm_verdict_response) { double_response("REPLY — the message is benign and warrants a response.") }

      it "uses the first all-caps token" do
        expect(gatekeeper.assess(incoming: message)).to eq("REPLY")
      end
    end

    context "when the response chats around the verdict" do
      let(:llm_verdict_response) { double_response("After review I think this is NO_REPLY territory.") }

      it "scans for a known verdict in the body" do
        expect(gatekeeper.assess(incoming: message)).to eq("NO_REPLY")
      end
    end

    context "when the response is unparseable" do
      let(:llm_verdict_response) { double_response("hmm not sure") }

      it "fails open with REPLY (safe default — process the message)" do
        expect(gatekeeper.assess(incoming: message)).to eq("REPLY")
      end
    end

    context "when the verdict is ABORT" do
      let(:llm_verdict_response) { double_response("ABORT") }

      it "raises ThreatDetected" do
        expect { gatekeeper.assess(incoming: message) }
          .to raise_error(SynthWorld::Synthetic::Gatekeeper::ThreatDetected, /input gated/)
      end
    end

    context "when the response only mentions ABORT in a denial" do
      let(:llm_verdict_response) { double_response("REPLY, this is not an ABORT case") }

      it "honours the first all-caps token (REPLY) instead of false-positiving on ABORT" do
        expect(gatekeeper.assess(incoming: message)).to eq("REPLY")
      end
    end
  end

  describe "#evaluate" do
    context "with a clean verdict" do
      let(:llm_verdict_response) { double_response("HIGH_QUALITY") }

      it "returns the verdict" do
        expect(gatekeeper.evaluate(outgoing: reply)).to eq("HIGH_QUALITY")
      end
    end

    context "when the verdict is ABORT" do
      let(:llm_verdict_response) { double_response("ABORT") }

      it "raises ThreatDetected" do
        expect { gatekeeper.evaluate(outgoing: reply) }
          .to raise_error(SynthWorld::Synthetic::Gatekeeper::ThreatDetected, /output gated/)
      end
    end

    context "when the response is unparseable" do
      let(:llm_verdict_response) { double_response("dunno") }

      it "fails open with HIGH_QUALITY" do
        expect(gatekeeper.evaluate(outgoing: reply)).to eq("HIGH_QUALITY")
      end
    end
  end
end
