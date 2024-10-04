require "./eventing"
require "./waiters_module"
require "./global_timer_module"
require "./leaderboard_module"
require "./persist_data_module"

module Modules
  Event = Eventing.new
  Waiters = WaitersModule.new
  GlobalTimer = GlobalTimerModule.new
  Leaderboard = LeaderboardModule.new
  PersistData = PersistDataModule.new
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

def build_time_left_string (milliseconds)
    days_left =    milliseconds // 1000 // 60 // 60 // 24
    hours_left =   milliseconds // 1000 // 60 // 60 % 24
    minutes_left = milliseconds // 1000 // 60 % 60
    seconds_left = milliseconds // 1000 % 60

    output = ""

    output = append_time_to_string output, days_left, "day"
    output = append_time_to_string output, hours_left, "hour"
    output = append_time_to_string output, minutes_left, "minute"
    output = append_time_to_string output, seconds_left, "second"

    output
end
