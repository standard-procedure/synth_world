# frozen_string_literal: true

require "thor"
require "fileutils"

module SynthWorld
  class CLI < Thor
  end
end

require_relative "cli/command"
require_relative "cli/server"

module SynthWorld
  class CLI < Thor
    desc "server SUBCOMMAND", "Manage the SynthWorld gateway server"
    subcommand "server", CLI::Server
  end
end
