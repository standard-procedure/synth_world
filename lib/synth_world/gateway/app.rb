# frozen_string_literal: true

require "sinatra/base"
require "json"

module SynthWorld
  class Gateway::App < Sinatra::Base
    get "/" do
      content_type :json
      {status: "ok", synthetics: settings.synthetic_names}.to_json
    end

    get "/synthetics" do
      content_type :json
      # TODO: query each synthetic's Unix socket for live status
      {synthetics: settings.synthetic_names}.to_json
    end

    post "/synthetics/:name/messages" do
      content_type :json
      # TODO: route to synthetic's Unix socket at socket_dir/name.sock
      halt 404, {error: "synthetic not found"}.to_json unless settings.synthetic_names.include?(params[:name])
      {status: "queued"}.to_json
    end
  end
end
