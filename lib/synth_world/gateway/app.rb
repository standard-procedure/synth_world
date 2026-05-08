# frozen_string_literal: true

require "sinatra/base"
require "socket"
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
      halt 404, {error: "synthetic not found"}.to_json unless settings.synthetic_names.include?(params[:name])

      socket_path = "#{settings.socket_dir}/#{params[:name]}.sock"
      halt 503, {error: "synthetic not reachable"}.to_json unless File.exist?(socket_path)

      body = request.body.read
      reply_json = UNIXSocket.open(socket_path) do |conn|
        conn.write(body)
        conn.close_write
        conn.read
      end
      reply_json
    end
  end
end
