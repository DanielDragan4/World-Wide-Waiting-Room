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

