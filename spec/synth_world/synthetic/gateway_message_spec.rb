# frozen_string_literal: true

RSpec.describe SynthWorld::Synthetic::GatewayMessage do
  let(:time) { Time.new(2026, 5, 8, 9, 0, 0) }
  let(:llm_response) { RubyLLM::Message.new(role: :assistant, content: "Hi!") }
  let(:delivered) { [] }
  let(:reply_to) { ->(reply) { delivered << reply } }

  subject(:message) do
    described_class.new(contents: "hello", time: time, headers: {from: "baz"}, reply_to: reply_to)
  end

  it "is a Synthetic::Message" do
    expect(message).to be_a(SynthWorld::Synthetic::Message)
  end

  describe "#deliver" do
    let(:reply) { SynthWorld::Synthetic::Reply.new(message: message, response: llm_response) }

    it "calls reply_to with the reply" do
      message.deliver(reply)
      expect(delivered).to eq([reply])
    end
  end
end
