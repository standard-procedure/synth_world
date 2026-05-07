# frozen_string_literal: true

module SynthWorld
  class Synthetic::Processor < Literal::Data
    prop :synthetic, SynthWorld::Synthetic
    prop :rule, String

    def call
      Async(transient: true) do
        loop do
          perform
          Async::Task.yield
        end
      end
    end
    alias_method :start, :call

    def perform
      raise NotImplementedError
    end
  end
end
