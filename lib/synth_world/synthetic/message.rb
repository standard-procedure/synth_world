# frozen_string_literal: true

module SynthWorld
  class Synthetic::Message < Literal::Data
    prop :contents, String
    prop :from, String
    prop :attachment, _Nilable(String), default: -> { nil }
  end
end
