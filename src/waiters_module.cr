require "./modules"

struct WaiterData
  def initialize
    # Initialize waiter data here...
  end
end

class WaitersModule
  def initialize
    @waiters = Hash(Int64, WaiterData).new
  end

  def add_waiter (uid)
  end

  def remove_waiter (uid)
  end

  def get_waiter_data(uid)
  end

  def update_waiter_data(uid)
  end
end
