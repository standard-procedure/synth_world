# frozen_string_literal: true

module SynthWorld
  class Synthetic::Message < Literal::Data
    prop :contents, String
    prop :attachment, _Nilable(String)
    prop :time, Time, default: -> { Time.now }
    prop :headers, _Hash(Symbol, _Any), default: {}.freeze
  end
end
