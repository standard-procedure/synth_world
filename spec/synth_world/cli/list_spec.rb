# frozen_string_literal: true

require "net/http"
require "json"

RSpec.describe SynthWorld::CLI do
  def run(*args)
    described_class.start(args)
  end

  let(:synthetics_response) { '{"synthetics":["cher","dionne"]}' }
  let(:empty_response)      { '{"synthetics":[]}' }

  before { allow(Net::HTTP).to receive(:get).and_return(synthetics_response) }

  describe "#list" do
    it "requests the /synthetics endpoint on the default gateway" do
      run("list")
      expect(Net::HTTP).to have_received(:get).with(URI("http://localhost:7000/synthetics"))
    end

    it "uses a custom url when specified" do
      run("list", "--url", "192.168.1.100")
      expect(Net::HTTP).to have_received(:get).with(URI("http://192.168.1.100:7000/synthetics"))
    end

    it "uses a custom port when specified" do
      run("list", "--port", "8080")
      expect(Net::HTTP).to have_received(:get).with(URI("http://localhost:8080/synthetics"))
    end

    it "prints synthetic names in text format by default" do
      expect { run("list") }.to output(/cher/).to_stdout
      expect { run("list") }.to output(/dionne/).to_stdout
    end

    it "prints raw JSON with --format json" do
      expect { run("list", "--format", "json") }.to output(/"synthetics"/).to_stdout
    end

    it "says there are no synthetics when the list is empty" do
      allow(Net::HTTP).to receive(:get).and_return(empty_response)
      expect { run("list") }.to output(/no synthetics/i).to_stdout
    end

    it "reports a connection error and exits when the gateway is unreachable" do
      allow(Net::HTTP).to receive(:get).and_raise(Errno::ECONNREFUSED)
      expect { run("list") }.to raise_error(SystemExit)
    end
  end

  describe "ls alias" do
    it "invokes list" do
      run("ls")
      expect(Net::HTTP).to have_received(:get).with(URI("http://localhost:7000/synthetics"))
    end
  end
end
