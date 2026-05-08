# frozen_string_literal: true

require "tmpdir"

RSpec.describe SynthWorld::Synthetic do
  let(:tmpdir) { Dir.mktmpdir("synth_test") }
  after { FileUtils.rm_rf(tmpdir) }

  let(:time) { Time.new(2026, 5, 8, 9, 0, 0) }
  let(:message) { SynthWorld::Synthetic::Message.new(contents: "hi", time: time, headers: {from: "baz"}) }
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

  describe ".from_file" do
    let(:yaml_path) { "#{tmpdir}/cher.yml" }
    before do
      File.write(yaml_path, <<~YAML)
        name: cher
        biography: a digital assistant
        workspace: #{tmpdir}/synth-workspace
        rules:
          operating_system: "Be helpful"
          gatekeeper_input_rule: "Assess"
          gatekeeper_output_rule: "Evaluate"
      YAML
    end

    it "builds a Synthetic with name, biography, and workspace" do
      synth = described_class.from_file(yaml_path)
      expect(synth.instance_variable_get(:@name)).to eq("cher")
      expect(synth.instance_variable_get(:@biography)).to eq("a digital assistant")
      expect(synth.instance_variable_get(:@workspace)).to eq("#{tmpdir}/synth-workspace")
    end

    it "converts rules keys to symbols" do
      synth = described_class.from_file(yaml_path)
      expect(synth.instance_variable_get(:@rules)[:operating_system]).to eq("Be helpful")
    end

    it "injects the supplied contexts" do
      synth = described_class.from_file(yaml_path, main_context: main_context)
      expect(synth.instance_variable_get(:@main_context)).to eq(main_context)
    end

    it "wires up a default Memory processor" do
      synth = described_class.from_file(yaml_path)
      processors = synth.instance_variable_get(:@processors)
      expect(processors[:memory]).to be_a(SynthWorld::Synthetic::Memory)
    end
  end

  describe "#generate_message_history" do
    let(:synth) do
      described_class.new(
        name: "test", biography: "test", workspace: tmpdir,
        rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: ""}
      )
    end

    it "returns the contents of working memory from the memory processor" do
      memory = synth.instance_variable_get(:@processors)[:memory]
      memory.process_incoming(SynthWorld::Synthetic::Message.new(contents: "earlier message", time: time, headers: {from: "baz"}))
      Async do
        action, args = memory.queue.pop
        memory.instance_exec(*args, &action)
      end
      expect(synth.generate_message_history).to include("earlier message")
    end

    it "returns an empty string when there is no memory processor" do
      synth_without_memory = described_class.new(
        name: "no-mem", biography: "x", workspace: tmpdir,
        rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: ""},
        processors: {}
      )
      expect(synth_without_memory.generate_message_history).to eq("")
    end
  end

  describe "#safe_process" do
    it "delivers an ErrorResponse via the message when process raises" do
      delivered = []
      gateway_msg = SynthWorld::Synthetic::GatewayMessage.new(
        contents: "hi", time: time, headers: {from: "baz"},
        reply_to: ->(r) { delivered << r }
      )

      # Stub process to raise — exercises the rescue in safe_process
      allow(synthetic).to receive(:process).and_raise(StandardError, "auth failed")

      synthetic.send(:safe_process, gateway_msg)

      expect(delivered.length).to eq(1)
      expect(delivered.first).to be_a(SynthWorld::Synthetic::ErrorResponse)
      expect(delivered.first.error).to eq("auth failed")
    end

    it "does not raise when delivery itself fails" do
      failing_class = Class.new(SynthWorld::Synthetic::Message) do
        def deliver(_)
          raise StandardError, "deliver crashed"
        end
      end
      bad_msg = failing_class.new(contents: "hi", time: time, headers: {from: "baz"})
      allow(synthetic).to receive(:process).and_raise(StandardError, "boom")

      expect { synthetic.send(:safe_process, bad_msg) }.not_to raise_error
    end
  end

  describe "#dispatch + main loop" do
    # Async::Queue#async runs the block inside an Async::Task that calls
    # block.(task, *args). The block signature must take the task first,
    # otherwise the queue item gets bound to whatever name and we end up
    # passing an Async::Task to #process.
    it "passes the queue item (not the Async::Task) to #process" do
      received = []

      captured_class = Class.new(described_class) do
        define_method(:process) { |msg| received << msg }
      end

      synth = captured_class.new(
        name: "loop-test", biography: "loop-test", workspace: tmpdir,
        rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: ""},
        processors: {},
        main_context: main_context
      )

      Async do |task|
        Async { synth.send(:start_main_loop) }
        synth.dispatch(message)
        task.sleep(0.05)
        synth.stop
      end

      expect(received).to eq([message])
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
