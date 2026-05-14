# frozen_string_literal: true

require "literal"
require "yaml"

module Plumbing
  class Error < StandardError; end
end

require_relative "plumbing/version"
require_relative "plumbing/types"
require_relative "plumbing/actor"

module Kernel
  def Await(&block)
    result = block.call
    result.respond_to?(:await) ? result.await : result
  end
  alias_method :await, :Await
end
