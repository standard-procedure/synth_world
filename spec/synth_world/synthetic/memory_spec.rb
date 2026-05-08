# frozen_string_literal: true

require "async"
require "tmpdir"

RSpec.describe SynthWorld::Synthetic::Memory do
  let(:tmpdir) { Dir.mktmpdir("synth_memory_test") }
  let(:time)   { Time.new(2026, 5, 7, 9, 0, 0) }
  after { FileUtils.rm_rf(tmpdir) }

  let(:synthetic) do
    SynthWorld::Synthetic.new(
      name: "test", biography: "test", workspace: tmpdir,
      rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: ""},
      processors: {}
    )
  end

  let(:workspace) { "#{tmpdir}/test_memory" }
  before { FileUtils.mkdir_p(workspace) }

  subject(:memory) { described_class.new(synthetic: synthetic, workspace: workspace) }

  let(:working_memory) { File.read("#{workspace}/working.md") }
  let(:llm_response)   { RubyLLM::Message.new(role: :assistant, content: "Hi there!") }

  # Drain N items from the queue by processing them inside an Async block.
  # This avoids starting the infinite loop, keeping reactor teardown clean.
  def drain(count)
    Async do
      count.times do
        action, args = memory.queue.pop
        memory.instance_exec(*args, &action)
      end
    end
  end

  describe "#process_incoming" do
    let(:message) { SynthWorld::Synthetic::Message.new(contents: "Hello", time: time, headers: {from: "baz"}) }

    it "appends the message to the working memory file" do
      memory.process_incoming(message)
      drain(1)
      expect(working_memory).to include("Hello")
    end

    it "records the sender" do
      memory.process_incoming(message)
      drain(1)
      expect(working_memory).to include("from: baz")
    end

    it "records the timestamp" do
      memory.process_incoming(message)
      drain(1)
      expect(working_memory).to include(time.utc.iso8601)
    end

    it "appends rather than overwrites" do
      msg2 = SynthWorld::Synthetic::Message.new(contents: "Again", time: time, headers: {from: "baz"})
      memory.process_incoming(message)
      memory.process_incoming(msg2)
      drain(2)
      expect(working_memory).to include("Hello")
      expect(working_memory).to include("Again")
    end
  end

  describe "#process_outgoing" do
    let(:message) { SynthWorld::Synthetic::Message.new(contents: "Hello", time: time, headers: {from: "baz"}) }
    let(:reply)   { SynthWorld::Synthetic::Reply.new(message: message, response: llm_response, headers: {"replying-to": "baz"}) }

    it "appends the reply to the working memory file" do
      memory.process_outgoing(reply)
      drain(1)
      expect(working_memory).to include("Hi there!")
    end

    it "records who was replied to" do
      memory.process_outgoing(reply)
      drain(1)
      expect(working_memory).to include("replying-to: baz")
    end
  end

  describe "ordering" do
    let(:message) { SynthWorld::Synthetic::Message.new(contents: "Hello", time: time, headers: {from: "baz"}) }
    let(:reply)   { SynthWorld::Synthetic::Reply.new(message: message, response: llm_response) }

    it "preserves incoming-then-outgoing order" do
      memory.process_incoming(message)
      memory.process_outgoing(reply)
      drain(2)
      expect(working_memory.index("Hello")).to be < working_memory.index("Hi there!")
    end
  end
end
