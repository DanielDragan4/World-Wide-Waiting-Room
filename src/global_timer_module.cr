require "./modules"

class GlobalTimerModule
  def initialize
    start_timer_fiber
  end

  def start_timer_fiber
    puts "Global Timer Fiber Started."
    spawn do
      loop do
        Modules::Event.emit({ :global_timer, { "timer" => Int64.new 35 } })
        sleep 1
        Fiber.yield
      end
    end
  end
end
