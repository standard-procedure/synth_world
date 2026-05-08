# frozen_string_literal: true

require "net/http"
require "json"

module SynthWorld
  class CLI < Thor
    desc "list", "List synthetics and their status (aliased as `ls`)"
    method_option :url, aliases: "-u", default: "localhost", desc: "Gateway host"
    method_option :port, aliases: "-p", type: :numeric, default: 7000, desc: "Gateway port"
    method_option :format, aliases: "-f", default: "text", desc: "Output format: text, json"
    def list
      uri = URI("http://#{options[:url]}:#{options[:port]}/synthetics")
      body = Net::HTTP.get(uri)
      data = JSON.parse(body)

      if options[:format] == "json"
        puts body
      else
        synthetics = data["synthetics"] || []
        synthetics.empty? ? say("No synthetics configured") : synthetics.each { |name| say name }
      end
    rescue Errno::ECONNREFUSED
      warn "Could not connect to gateway at #{options[:url]}:#{options[:port]}"
      exit 1
    end

    map "ls" => "list"
  end
end
