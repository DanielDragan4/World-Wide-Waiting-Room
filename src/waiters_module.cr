require "./modules"

alias WaiterTup = Tuple(String, Int64 | Int32, String, String)

class Waiter
  getter timewaited

  def initialize (
    @uid : String,
    @timewaited : Int64,
    @name : String = "Anonymous"
  )
    @channel = Channel(Nil).new
    start_waiter_fiber
  end

  def serialize
    {
      @uid,
      @timewaited,
      (build_time_left_string @timewaited),
      @name
    }
  end

  def add (milliseconds)
    @timewaited += milliseconds
    if @timewaited < 0
      @timewaited = 0
    end
  end

  def kill
    @channel.close
  end

  def emit
    Modules::Event.emit({ :waiter_updated, { "uid" => @uid, "time_left" => build_time_left_string @timewaited } of String => EventHashValue })
  end

  def start_waiter_fiber
    spawn do
      loop do
        @timewaited += 1000
        emit
        break if @channel.closed?
        sleep 1
        Fiber.yield
      end
    end
  end
end

class WaitersModule
  getter waiters

  def initialize
    @waiters = Hash(String, Waiter).new
  end

  def give (amount : Int64, to, from)
    if (f = @waiters.fetch(from, nil)) && (t = @waiters.fetch(to, nil))
      if f.timewaited >= amount
        f.add(-amount)
        t.add(amount)
      end
    end
  end

  def take (amount, from, to)
    give amount, from, to
  end

  def get_waiter (uid)
    if waiter = @waiters.fetch uid, nil
      return waiter.serialize
    end

    nil
  end

  def add_waiter (uid)
    @waiters[uid] = Waiter.new uid, 0
  end

  def remove_waiter (uid)
    begin
      @waiters[uid].kill
      @waiters.delete uid
    rescue
    end
  end
end
