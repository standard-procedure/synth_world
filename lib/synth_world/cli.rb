# frozen_string_literal: true

require "thor"
require "fileutils"

module SynthWorld
  class CLI < Thor
  end
end

require_relative "cli/command"
require_relative "cli/server"
require_relative "cli/list"

module SynthWorld
  class CLI < Thor
    desc "server [COMMAND]", "Manage the SynthWorld gateway server (aliased as `gateway`)"
    subcommand "server", CLI::Server
    map "gateway" => "server"
  end
end
