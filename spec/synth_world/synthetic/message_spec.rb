# frozen_string_literal: true

RSpec.describe SynthWorld::Synthetic::Message do
  let(:time) { Time.new(2026, 5, 7, 9, 0, 0) }
  subject(:message) { described_class.new(contents: "Hello", time: time, headers: {from: "baz"}) }

  it "records the contents" do
    expect(message.contents).to eq("Hello")
  end

  it "defaults attachment to nil" do
    expect(message.attachment).to be_nil
  end

  it "accepts an attachment" do
    msg = described_class.new(contents: "See this", attachment: "some file content", headers: {from: "baz"})
    expect(msg.attachment).to eq("some file content")
  end
end
