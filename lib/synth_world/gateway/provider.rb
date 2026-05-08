# frozen_string_literal: true

module SynthWorld
  class Gateway::Provider < Literal::Data
    prop :name, String
    prop :provider, Symbol
    prop :model, String
    prop :api_base, _Nilable(String)
  end
end
