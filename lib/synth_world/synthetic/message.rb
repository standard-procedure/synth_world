# frozen_string_literal: true

module SynthWorld
  class Synthetic::Message < Literal::Data
    prop :contents, String
    prop :from, String
    prop :time, Time, default: -> { Time.now }
    prop :attachment, _Nilable(String)

    def to_memory
      <<~MEMORY
        - #{@time.iso8601} - from: #{@from}, attachment: #{@attachment.nil? ? "-" : @attachment}
          #{@contents}
      MEMORY
    end
  end
end
