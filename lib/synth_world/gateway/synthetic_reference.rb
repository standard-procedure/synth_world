# frozen_string_literal: true

module SynthWorld
  class Gateway::SyntheticReference < Literal::Data
    prop :name, String
    prop :config_path, String
  end
end
