# frozen_string_literal: true

require "fileutils"
require "async/container"

module SynthWorld
  class Gateway < Literal::Data
  end
end

require_relative "gateway/synthetic_reference"
require_relative "gateway/configuration"
require_relative "gateway/app"

module SynthWorld
  class Gateway < Literal::Data
    prop :config, SynthWorld::Gateway::Configuration

    def start
      redirect_output
      start_container
    end

    private

    def redirect_output
      FileUtils.mkdir_p(File.dirname(@config.log_file))
      $stdout.reopen(@config.log_file, "a")
      $stderr.reopen(@config.log_file, "a")
      $stdout.sync = $stderr.sync = true
    end

    def start_container
      container = Async::Container::Forked.new

      container.spawn(name: "gateway-http") { start_http_server }

      @config.synthetics.each do |ref|
        container.spawn(name: ref.name) { start_synthetic(ref) }
      end

      container.wait
    end

    def start_http_server
      Gateway::App.set :synthetic_names, @config.synthetics.map(&:name)
      Gateway::App.run!(port: @config.port, bind: @config.bind, server: %w[falcon webrick])
    end

    def start_synthetic(ref)
      # TODO: load ref.config_path, build Synthetic, connect Unix socket, start loop
      loop { sleep 10 }
    end
  end
end
