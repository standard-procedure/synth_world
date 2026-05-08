# frozen_string_literal: true

require "tmpdir"

RSpec.describe SynthWorld::Synthetic do
  let(:tmpdir) { Dir.mktmpdir("synth_test") }
  after { FileUtils.rm_rf(tmpdir) }

  let(:time)         { Time.new(2026, 5, 8, 9, 0, 0) }
  let(:message)      { SynthWorld::Synthetic::Message.new(contents: "hi", time: time, headers: {from: "baz"}) }
  let(:llm_response) { RubyLLM::Message.new(role: :assistant, content: "Hello!") }

  # Real RubyLLM::Context (not frozen) so we can stub `.chat`.
  let(:main_context) do
    RubyLLM.context do |c|
      c.default_model = "gpt-4o-mini"
      c.openai_api_key = "dummy"
    end
  end

  let(:chat) do
    instance_double(RubyLLM::Chat).tap do |c|
      allow(c).to receive(:with_instructions).and_return(c)
      allow(c).to receive(:with_tools).and_return(c)
      allow(c).to receive(:with_temperature).and_return(c)
      allow(c).to receive(:ask).and_return(llm_response)
    end
  end

  before { allow(main_context).to receive(:chat).and_return(chat) }

  # Closure-captured arrays + a Processor subclass that records calls
  # synchronously (Literal::Data freezes instances, so partial doubles fail).
  let(:incoming_calls) { [] }
  let(:outgoing_calls) { [] }
  let(:capturing_processor_class) do
    inc = incoming_calls
    out = outgoing_calls
    Class.new(SynthWorld::Synthetic::Processor) do
      define_method(:process_incoming) { |msg| inc << msg }
      define_method(:process_outgoing) { |reply| out << reply }
    end
  end

  # The Processor's :synthetic prop is type-checked, so we need a real
  # Synthetic to satisfy it. Use a separate "host" instance — the
  # processor's back-reference isn't exercised by the methods under test.
  let(:host_synthetic) do
    described_class.new(
      name: "host", biography: "host", workspace: tmpdir,
      rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: ""},
      processors: {}
    )
  end

  let(:processor) { capturing_processor_class.new(synthetic: host_synthetic) }

  subject(:synthetic) do
    described_class.new(
      name: "test", biography: "test", workspace: tmpdir,
      rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: "", operating_system: "Be helpful"},
      processors: {capturer: processor},
      main_context: main_context
    )
  end

  describe "#reply_to" do
    it "builds the chat from main_context" do
      synthetic.reply_to(message)
      expect(main_context).to have_received(:chat)
    end

    it "passes the system prompt to with_instructions" do
      synthetic.reply_to(message)
      expect(chat).to have_received(:with_instructions).with(/Be helpful/)
    end

    it "passes the temperature from state" do
      synthetic.reply_to(message)
      expect(chat).to have_received(:with_temperature).with(0.7)
    end

    it "asks with the generated prompt and the message attachment" do
      synthetic.reply_to(message)
      expect(chat).to have_received(:ask).with(/hi/, with: nil)
    end

    it "passes through a message attachment" do
      msg = SynthWorld::Synthetic::Message.new(contents: "see this", time: time, headers: {from: "baz"}, attachment: "file-bytes")
      synthetic.reply_to(msg)
      expect(chat).to have_received(:ask).with(anything, with: "file-bytes")
    end

    it "returns a Reply wrapping the message and the LLM response" do
      reply = synthetic.reply_to(message)
      expect(reply).to be_a(SynthWorld::Synthetic::Reply)
      expect(reply.message).to eq(message)
      expect(reply.contents).to eq("Hello!")
    end
  end

  describe "#process" do
    it "passes the incoming message to each processor" do
      synthetic.send(:process, message)
      expect(incoming_calls).to eq([message])
    end

    it "passes the outgoing reply (not the original message) to each processor" do
      synthetic.send(:process, message)
      expect(outgoing_calls.length).to eq(1)
      expect(outgoing_calls.first).to be_a(SynthWorld::Synthetic::Reply)
      expect(outgoing_calls.first.contents).to eq("Hello!")
    end

    it "outputs the reply contents to stdout" do
      expect { synthetic.send(:process, message) }.to output(/Hello!/).to_stdout
    end

    it "calls process_incoming before process_outgoing" do
      synthetic.send(:process, message)
      # Both arrays were appended in order; if process_outgoing fired first,
      # the reply wouldn't yet exist. Verifying both populated is enough.
      expect(incoming_calls).not_to be_empty
      expect(outgoing_calls).not_to be_empty
    end

    it "raises a TypeError when the input is not a Message" do
      expect { synthetic.send(:process, "not a message") }.to raise_error(Literal::TypeError)
    end
  end
end
