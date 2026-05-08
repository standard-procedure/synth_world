# frozen_string_literal: true

require "net/http"
require "json"

RSpec.describe SynthWorld::CLI do
  def run(*args)
    described_class.start(args)
  end

  let(:reply_body) { '{"contents":"Hi back!","time":"2026-05-08T09:00:00+01:00","headers":{"replying_to":"Baz"}}' }

  let(:successful_response) do
    instance_double(Net::HTTPOK, is_a?: true, body: reply_body, code: "200")
  end

  before { allow(Net::HTTP).to receive(:post).and_return(successful_response) }

  describe "#message" do
    it "POSTs to the synth's messages endpoint with contents and from header" do
      run("message", "cher", "--message", "hi", "--from", "Baz")
      expect(Net::HTTP).to have_received(:post).with(
        URI("http://localhost:7000/synthetics/cher/messages"),
        '{"contents":"hi","headers":{"from":"Baz"}}',
        hash_including("Content-Type" => "application/json")
      )
    end

    it "uses a custom url and port when specified" do
      run("message", "cher", "--message", "hi", "--from", "Baz", "--url", "192.168.1.1", "--port", "8080")
      expect(Net::HTTP).to have_received(:post).with(
        URI("http://192.168.1.1:8080/synthetics/cher/messages"),
        anything, anything
      )
    end

    it "prints the reply contents in text format by default" do
      expect { run("message", "cher", "--message", "hi", "--from", "Baz") }
        .to output(/Hi back!/).to_stdout
    end

    it "prints the raw JSON with --format json" do
      expect { run("message", "cher", "--message", "hi", "--from", "Baz", "--format", "json") }
        .to output(/"contents":"Hi back!"/).to_stdout
    end

    it "reports a connection error and exits when the gateway is unreachable" do
      allow(Net::HTTP).to receive(:post).and_raise(Errno::ECONNREFUSED)
      expect { run("message", "cher", "--message", "hi", "--from", "Baz") }.to raise_error(SystemExit)
    end

    it "exits with an error when the gateway returns a non-success status" do
      error_response = instance_double(Net::HTTPNotFound, is_a?: false, body: '{"error":"synthetic not found"}', code: "404")
      allow(Net::HTTP).to receive(:post).and_return(error_response)
      expect { run("message", "unknown", "--message", "hi", "--from", "Baz") }.to raise_error(SystemExit)
    end
  end
end
