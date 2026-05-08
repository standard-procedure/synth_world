# frozen_string_literal: true

RSpec.describe SynthWorld::Synthetic::ErrorResponse do
  let(:time) { Time.new(2026, 5, 8, 9, 0, 0) }
  let(:message) { SynthWorld::Synthetic::Message.new(contents: "hi", time: time, headers: {from: "baz"}) }
  subject(:err) { described_class.new(message: message, error: "auth failed") }

  describe "#to_h" do
    it "includes the error string" do
      expect(err.to_h[:error]).to eq("auth failed")
    end

    it "includes a timestamp" do
      expect(err.to_h[:time]).to be_a(String)
    end

    it "echoes who was being replied to" do
      expect(err.to_h[:replying_to]).to eq("baz")
    end
  end

  describe "#to_json" do
    it "round-trips through JSON" do
      parsed = JSON.parse(err.to_json)
      expect(parsed["error"]).to eq("auth failed")
      expect(parsed["replying_to"]).to eq("baz")
    end
  end
end
