# frozen_string_literal: true

module SynthWorld
  class CLI::Server < CLI::Command
    DEFAULT_CONFIG = "~/.config/synth/config.yml"

    desc "start", "Start the gateway server"
    method_option :config, aliases: "-c", desc: "Gateway configuration file", default: DEFAULT_CONFIG
    def start
      config_path = File.expand_path(options[:config])
      unless File.exist?(config_path)
        warn "Config file not found: #{config_path}"
        exit 1
      end

      config = Gateway::Configuration.from_file(config_path)

      if running?(config.pid_file)
        say "Gateway is already running (PID #{File.read(config.pid_file).strip})"
        exit 1
      end

      FileUtils.mkdir_p(File.dirname(config.pid_file))
      FileUtils.mkdir_p(config.socket_dir)

      pid = Process.fork { Gateway.new(config: config).start }
      Process.detach(pid)
      File.write(config.pid_file, pid.to_s)

      say "Gateway started on port #{config.port} (PID #{pid})"
      say "Log: #{config.log_file}"
    end

    desc "status", "Show gateway server status"
    method_option :config, aliases: "-c", desc: "Gateway configuration file", default: DEFAULT_CONFIG
    def status
      config = Gateway::Configuration.from_file(File.expand_path(options[:config]))
      if running?(config.pid_file)
        say "Gateway is running (PID #{File.read(config.pid_file).strip})"
      else
        say "Gateway is not running"
      end
    end

    desc "stop", "Stop the gateway server"
    method_option :config, aliases: "-c", desc: "Gateway configuration file", default: DEFAULT_CONFIG
    def stop
      config = Gateway::Configuration.from_file(File.expand_path(options[:config]))

      unless File.exist?(config.pid_file)
        say "Gateway is not running"
        return
      end

      pid = File.read(config.pid_file).strip.to_i
      Process.kill("TERM", pid)
      File.delete(config.pid_file)
      say "Gateway stopped (PID #{pid})"
    rescue Errno::ESRCH
      File.delete(config.pid_file) if File.exist?(config.pid_file)
      say "Gateway was not running (stale PID file removed)"
    end

    private

    def running?(pid_file)
      return false unless File.exist?(pid_file)
      pid = File.read(pid_file).strip.to_i
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end
  end
end
