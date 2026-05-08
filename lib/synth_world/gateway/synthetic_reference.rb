# frozen_string_literal: true

module SynthWorld
  class Gateway::SyntheticReference < Literal::Data
    prop :name, String
    prop :config_path, String
    prop :main_provider, String, default: "default"
    prop :processing_provider, String, default: "evaluation"
    prop :embedding_provider, String, default: "embedding"
    prop :gatekeeper_provider, String, default: "gatekeeper"
  end
end
