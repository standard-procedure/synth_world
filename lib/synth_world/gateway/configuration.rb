# frozen_string_literal: true

require "yaml"

module SynthWorld
  class Gateway::Configuration < Literal::Data
    prop :port, _Integer, default: 7000
    prop :bind, String, default: "127.0.0.1"
    prop :socket_dir, String, default: "/tmp/synth"
    prop :pid_file, String, default: "/tmp/synth/synth.pid"
    prop :log_file, String, default: "/tmp/synth/synth.log"
    prop :synthetics, _Array(Gateway::SyntheticReference), default: -> { [] }

    def self.from_file(path)
      data = YAML.safe_load_file(path)
      new(
        port: data["port"] || 7000,
        bind: data["bind"] || "127.0.0.1",
        socket_dir: File.expand_path(data["socket_dir"] || "/tmp/synth"),
        pid_file: File.expand_path(data["pid_file"] || "/tmp/synth/synth.pid"),
        log_file: File.expand_path(data["log_file"] || "/tmp/synth/synth.log"),
        synthetics: (data["synthetics"] || []).map { |s|
          Gateway::SyntheticReference.new(
            name: s["name"],
            config_path: File.expand_path(s["config"])
          )
        }
      )
    end
  end
end
