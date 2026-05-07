# frozen_string_literal: true

require_relative "synth_world/version"

module SynthWorld
  class Error < StandardError; end
  require_relative "synth_world/types"
  require_relative "synth_world/synthetic"
end
