# frozen_string_literal: true

require "rack/test"
require "tmpdir"

RSpec.describe SynthWorld::Gateway::App do
  include Rack::Test::Methods

  def app
    SynthWorld::Gateway::App
  end

  let(:tmpdir) { Dir.mktmpdir("gateway_app_test") }
  after { FileUtils.rm_rf(tmpdir) }

  before do
    app.set :synthetic_names, ["cher", "dionne"]
    app.set :socket_dir, tmpdir
    app.set :host_authorization, permitted_hosts: []
  end

  describe "GET /synthetics" do
    it "returns the configured synthetic names" do
      get "/synthetics"
      expect(JSON.parse(last_response.body)["synthetics"]).to eq(["cher", "dionne"])
    end
  end

  describe "POST /synthetics/:name/messages" do
    let(:socket_path) { "#{tmpdir}/cher.sock" }

    it "returns 404 when the synthetic is not configured" do
      post "/synthetics/unknown/messages", '{"contents":"hi"}'
      expect(last_response.status).to eq(404)
    end

    it "returns 503 when the synthetic's socket file is missing" do
      post "/synthetics/cher/messages", '{"contents":"hi"}'
      expect(last_response.status).to eq(503)
    end

    context "with a backing socket" do
      let(:reply_json) { '{"contents":"Hi back!","time":"2026-05-08T09:00:00+01:00","headers":{"replying_to":"baz"}}' }

      it "writes the body to the socket and returns the reply" do
        # Stub UNIXSocket.open to simulate a backing synth process
        sock = instance_double(UNIXSocket)
        allow(sock).to receive(:write)
        allow(sock).to receive(:close_write)
        allow(sock).to receive(:read).and_return(reply_json)
        # The endpoint also checks File.exist? on the socket path
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(socket_path).and_return(true)
        allow(UNIXSocket).to receive(:open).with(socket_path).and_yield(sock)

        post "/synthetics/cher/messages", '{"contents":"hi"}', {"CONTENT_TYPE" => "application/json"}

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(reply_json)
        expect(sock).to have_received(:write).with('{"contents":"hi"}')
      end
    end
  end
end
