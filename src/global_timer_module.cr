require "./modules"

class GlobalTimerModule
  def initialize
    @timeleft = 600000000
    start_timer_fiber
  end

  def increase_by (milliseconds)
    @timeleft += milliseconds
  end

  def decrease_by (milliseconds)
    @timeleft -= milliseconds
  end

  def current_time_left
    build_time_left_string @timeleft
  end

  def emit
    Modules::Event.emit({ :global_timer, { "time_left" => current_time_left } of String => EventHashValue })
  end

  def start_timer_fiber
    puts "Global Timer Fiber Started."
    spawn do
      loop do
        if @timeleft == 0
          next
        end

        emit
        @timeleft -= 1000
        Modules::Leaderboard.compute
        sleep 1
        Fiber.yield
      end
    end
  end
end
