# # frozen_string_literal: true

module SynthWorld
  class Synthetic::Memory < Synthetic::Processor
    prop :workspace, String

    action :record_incoming do |message|
      Literal.check message, Synthetic::Message
      File.write "#{workspace}/working.md", message.to_memory, mode: "a+"
    end

    action :record_outgoing do |reply|
      Literal.check reply, Synthetic::Reply
      File.write "#{workspace}/working.md", reply.to_memory, mode: "a+"
    end
  end
end
