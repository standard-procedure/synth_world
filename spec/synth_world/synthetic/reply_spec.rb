# frozen_string_literal: true

RSpec.describe SynthWorld::Synthetic::Reply do
  let(:time) { Time.new(2026, 5, 7, 9, 0, 0) }
  let(:message) { SynthWorld::Synthetic::Message.new(contents: "Hello", time: time, headers: {from: "baz"}) }
  let(:llm_response) { RubyLLM::Message.new(role: :assistant, content: "Hi there!") }
  subject(:reply) { described_class.new(message: message, response: llm_response) }

  it "exposes the response contents" do
    expect(reply.contents).to eq("Hi there!")
  end
end
