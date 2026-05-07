# frozen_string_literal: true

RSpec.describe SynthWorld::Synthetic::Message do
  let(:time) { Time.new(2026, 5, 7, 9, 0, 0) }
  subject(:message) { described_class.new(contents: "Hello", from: "baz", time: time) }

  it "records who sent it" do
    expect(message.from).to eq("baz")
  end

  it "records the contents" do
    expect(message.contents).to eq("Hello")
  end

  it "defaults attachment to nil" do
    expect(message.attachment).to be_nil
  end

  it "accepts an attachment" do
    msg = described_class.new(contents: "See this", from: "baz", attachment: "some file content")
    expect(msg.attachment).to eq("some file content")
  end

  describe "#to_memory" do
    it "includes the timestamp" do
      expect(message.to_memory).to include(time.iso8601)
    end

    it "includes the sender" do
      expect(message.to_memory).to include("from: baz")
    end

    it "includes the contents" do
      expect(message.to_memory).to include("Hello")
    end

    it "shows a dash when there is no attachment" do
      expect(message.to_memory).to include("attachment: -")
    end

    it "shows the attachment when present" do
      msg = described_class.new(contents: "See this", from: "baz", time: time, attachment: "some file content")
      expect(msg.to_memory).to include("attachment: some file content")
    end
  end
end
