require "./modules"

class GlobalTimerModule
  def initialize
    @timeleft = 60000
    start_timer_fiber
  end

  def append_time_to_string (str, value, unit)
    if value > 0
      str = "#{str}#{value} #{unit}"
      if value > 1
        str = "#{str}s"
      end
      str = "#{str} "
    end
    str
  end

  def time_left_string
    days_left = @timeleft // 1000 // 60 // 60 // 24
    hours_left = @timeleft // 1000 // 60 // 60 % 24
    minutes_left = @timeleft // 1000 // 60 % 60
    seconds_left = @timeleft // 1000 % 60

    output = ""

    output = append_time_to_string output, days_left, "day"
    output = append_time_to_string output, hours_left, "hour"
    output = append_time_to_string output, minutes_left, "minute"
    output = append_time_to_string output, seconds_left, "second"

    output
  end

  def start_timer_fiber
    puts "Global Timer Fiber Started."
    spawn do
      loop do
        Modules::Event.emit({ :global_timer, { "time_left" => time_left_string } of String => EventHashValue })
        @timeleft -= 1
        sleep 0.001
        Fiber.yield
      end
    end
  end
end
