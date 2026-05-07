# frozen_string_literal: true

module SynthWorld
  module Types
    def _OneOf(*values) = proc { |v| values.include? v }
    def _SomeOf(*values) = proc { |v| (v - values).empty? }
  end
end
