# frozen_string_literal: true

module SynthWorld
  class CLI::Command < Thor
    def self.banner(command, _namespace = nil, subcommand = false)
      "#{basename} #{subcommand_prefix} #{command.usage}"
    end

    def self.subcommand_prefix
      name.gsub(%r{.*::}, "").gsub(/^[A-Z]/) { |m| m.downcase }.gsub(/[A-Z]/) { |m| "-#{m.downcase}" }
    end
  end
end
