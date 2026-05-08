# frozen_string_literal: true

module SynthWorld
  class Synthetic::Gatekeeper < Literal::Data
    prop :synthetic, SynthWorld::Synthetic
    prop :input_rule, String
    prop :output_rule, String

    def assess incoming:
    end

    def evaluate outgoing:
    end
  end
end
