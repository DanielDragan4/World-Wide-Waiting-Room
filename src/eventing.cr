require "uuid"

alias EventHashValue = String | Int32 | UUID | Int64 | Nil
alias EventHash = Hash(String, EventHashValue)
alias Event = Tuple(Symbol, EventHash)

class Eventing
  def initialize
    @channels = Hash(String, Channel(Event)).new
  end

  def register_channel (channel)
    uuid = UUID.v4.hexstring
    puts "Registered channel #{uuid}"
    @channels[uuid] = channel
    uuid
  end

  def unregister_channel (uuid)
    @channels.delete(uuid)
  end

  def emit (message : Event)
    @channels.each_value do |channel|
      channel.send message
    end
  end
end
