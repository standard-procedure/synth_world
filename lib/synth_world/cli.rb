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
    desc "gateway [COMMAND]", "Manage the SynthWorld gateway server"
    subcommand "gateway", CLI::Server
    desc "server [COMMAND]", "Alias for `gateway`"
    subcommand "server", CLI::Server
  end
end
