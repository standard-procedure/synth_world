# frozen_string_literal: true

RSpec.describe SynthWorld::Synthetic::Reply do
  let(:time) { Time.new(2026, 5, 7, 9, 0, 0) }
  let(:message) { SynthWorld::Synthetic::Message.new(contents: "Hello", time: time, headers: {from: "baz"}) }
  let(:llm_response) { RubyLLM::Message.new(role: :assistant, content: "Hi there!") }
  subject(:reply) { described_class.new(message: message, response: llm_response) }

  it "exposes the response contents" do
    expect(reply.contents).to eq("Hi there!")
  end

  describe "#headers" do
    it "includes replying_to derived from the message sender" do
      expect(reply.headers[:replying_to]).to eq("baz")
    end

    it "includes the response tokens" do
      expect(reply.headers).to have_key(:tokens)
    end

    it "merges explicitly provided headers" do
      r = described_class.new(message: message, response: llm_response, headers: {channel: "whatsapp"})
      expect(r.headers[:channel]).to eq("whatsapp")
    end
  end

  describe "#to_h" do
    it "includes the contents" do
      expect(reply.to_h[:contents]).to eq("Hi there!")
    end

    it "includes the message timestamp as an iso8601 string" do
      expect(reply.to_h[:time]).to eq(time.iso8601)
    end

    it "includes the headers" do
      expect(reply.to_h[:headers][:replying_to]).to eq("baz")
    end
  end

  describe "#to_json" do
    it "round-trips through JSON" do
      parsed = JSON.parse(reply.to_json)
      expect(parsed["contents"]).to eq("Hi there!")
      expect(parsed["time"]).to eq(time.iso8601)
      expect(parsed["headers"]["replying_to"]).to eq("baz")
    end
  end
end
