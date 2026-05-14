# frozen_string_literal: true

module Plumbing
  def self.OneOf(*values) = proc { |v| values.include? v }
end
