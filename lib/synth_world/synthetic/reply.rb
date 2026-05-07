# frozen_string_literal: true

module SynthWorld
  class Synthetic::Reply < Literal::Data
    prop :message, SynthWorld::Synthetic::Message
    prop :response, Object

    def contents = response.content
  end
end
