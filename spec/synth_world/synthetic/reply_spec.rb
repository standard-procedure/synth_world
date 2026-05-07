# frozen_string_literal: true

RSpec.describe SynthWorld::Synthetic::Reply do
  let(:time) { Time.new(2026, 5, 7, 9, 0, 0) }
  let(:message) { SynthWorld::Synthetic::Message.new(contents: "Hello", from: "baz", time: time) }
  let(:llm_response) { RubyLLM::Message.new(role: :assistant, content: "Hi there!") }
  subject(:reply) { described_class.new(message: message, response: llm_response) }

  it "exposes the response contents" do
    expect(reply.contents).to eq("Hi there!")
  end

  it "defaults replying_to from the message sender" do
    expect(reply.replying_to).to eq("baz")
  end

  it "allows replying_to to be overridden" do
    r = described_class.new(message: message, response: llm_response, replying_to: "everyone")
    expect(r.replying_to).to eq("everyone")
  end

  describe "#to_memory" do
    it "includes the message timestamp" do
      expect(reply.to_memory).to include(time.iso8601)
    end

    it "includes who is being replied to" do
      expect(reply.to_memory).to include("replying-to: baz")
    end

    it "includes the response contents" do
      expect(reply.to_memory).to include("Hi there!")
    end
  end
end
