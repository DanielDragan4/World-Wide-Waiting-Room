alias Event = Tuple(Symbol, Int128)

class Eventing
  def initialize
    @serial = Atomic(Int128).new 0
    @channels = Hash(Int128, Channel(Event)).new
  end

  def register_channel (channel)
    @serial.add 1
    puts "Registered channel #{@serial.get}"
    id = @serial.get
    @channels[id] = channel
    id
  end

  def unregister_channel (serial_id)
    @channels.delete(serial_id)
  end

  def emit (message)
    @channels.each_value do |channel|
      channel.send message
    end
  end
end
