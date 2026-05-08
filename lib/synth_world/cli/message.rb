# frozen_string_literal: true

require "net/http"
require "json"

module SynthWorld
  class CLI < Thor
    desc "message SYNTH", "Send a message to a synthetic and print the reply"
    method_option :message, aliases: "-m", required: true, desc: "Message contents"
    method_option :from, required: true, desc: "Sender identifier"
    method_option :url, aliases: "-u", default: "localhost", desc: "Gateway host"
    method_option :port, aliases: "-p", type: :numeric, default: 7000, desc: "Gateway port"
    method_option :format, aliases: "-f", default: "text", desc: "Output format: text, json"
    def message(synth)
      uri = URI("http://#{options[:url]}:#{options[:port]}/synthetics/#{synth}/messages")
      payload = {contents: options[:message], headers: {from: options[:from]}}.to_json
      response = Net::HTTP.post(uri, payload, "Content-Type" => "application/json")

      unless response.is_a?(Net::HTTPSuccess)
        warn "Gateway returned #{response.code}: #{response.body}"
        exit 1
      end

      if options[:format] == "json"
        puts response.body
      else
        data = JSON.parse(response.body)
        if data["error"]
          warn "Synth error: #{data["error"]}"
          exit 1
        end
        say data["contents"].to_s
      end
    rescue Errno::ECONNREFUSED
      warn "Could not connect to gateway at #{options[:url]}:#{options[:port]}"
      exit 1
    end
  end
end
