require "./modules"

struct WaiterData
  def initialize
    # Initialize waiter data here...
  end
end

class WaitersModule
  def initialize
    @waiters = Hash(UUID, WaiterData).new
  end

  def add_waiter (uid)
    puts "Tried to add waiter #{uid} but the method is not implemented."
  end

  def remove_waiter (uid)
    puts "Tried to remove waiter #{uid} but the method is not implemented."
  end
end
