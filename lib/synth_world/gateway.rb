# frozen_string_literal: true

require "fileutils"
require "json"
require "socket"
require "async"
require "async/container"

module SynthWorld
  class Gateway < Literal::Data
  end
end

require_relative "gateway/synthetic_reference"
require_relative "gateway/provider"
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

      container.spawn(name: "synth--gateway-http") { start_http_server }

      @config.synthetics.each do |ref|
        container.spawn(name: "synth--#{ref.name}") { start_synthetic(ref) }
      end

      # Async::Container::Forked installs TERM/INT traps in each forked child,
      # but the supervisor itself has no traps — it just blocks on `wait`. So
      # without these, `synth server stop` kills the supervisor immediately
      # and the children get orphaned. Raise Interrupt in the main thread so
      # we can wake `wait` up and stop the container gracefully.
      trap(:TERM) { Thread.main.raise(Interrupt) }
      trap(:INT) { Thread.main.raise(Interrupt) }

      begin
        container.wait
      rescue Interrupt
        container.stop
      end
    end

    def start_http_server
      Gateway::App.set :synthetic_names, @config.synthetics.map(&:name)
      Gateway::App.set :socket_dir, @config.socket_dir
      Gateway::App.run!(port: @config.port, bind: @config.bind, server: %w[falcon webrick])
    end

    def start_synthetic(ref)
      providers = providers_for(ref)
      synth = Synthetic.from_file(
        ref.config_path,
        main_context: providers[:main].context,
        main_provider: providers[:main].provider,
        processing_context: providers[:processing].context,
        processing_provider: providers[:processing].provider,
        embedding_context: providers[:embedding].context,
        embedding_provider: providers[:embedding].provider,
        gatekeeper_context: providers[:gatekeeper].context,
        gatekeeper_provider: providers[:gatekeeper].provider
      )

      socket_path = "#{@config.socket_dir}/#{ref.name}.sock"
      File.unlink(socket_path) if File.exist?(socket_path)
      server = UNIXServer.new(socket_path)

      Async do
        Async { synth.start }
        Async { accept_loop(synth, server) }
      end
    ensure
      synth&.stop
      begin
        server&.close
      rescue
        nil
      end
      File.unlink(socket_path) if socket_path && File.exist?(socket_path)
    end

    def accept_loop(synth, server)
      loop do
        conn = server.accept
        Async { handle_connection(synth, conn) }
      end
    end

    # Read one JSON request from the connection, dispatch a GatewayMessage
    # whose reply_to writes the JSON reply back, then close.
    def handle_connection(synth, conn)
      payload = JSON.parse(conn.read)
      message = Synthetic::GatewayMessage.new(
        contents: payload.fetch("contents"),
        attachment: payload["attachment"],
        headers: (payload["headers"] || {}).transform_keys(&:to_sym),
        # Defence in depth: always close the connection, even if write
        # fails — otherwise the HTTP gateway hangs reading from the socket.
        reply_to: ->(reply) {
          begin
            conn.write(reply.to_json)
          rescue
            nil
          ensure
            begin
              conn.close_write
            rescue
              nil
            end
          end
        }
      )
      synth.dispatch(message)
    rescue => e
      begin
        conn.write({error: e.message}.to_json)
      rescue
        nil
      end
      begin
        conn.close_write
      rescue
        nil
      end
    end

    def contexts_for(ref)
      providers_for(ref).transform_values(&:context)
    end

    def providers_for(ref)
      {
        main: @config.providers.fetch(ref.main_provider),
        processing: @config.providers.fetch(ref.processing_provider),
        embedding: @config.providers.fetch(ref.embedding_provider),
        gatekeeper: @config.providers.fetch(ref.gatekeeper_provider)
      }
    end
  end
end
