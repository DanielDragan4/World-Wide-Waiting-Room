require "./modules"

class LeaderboardModule
  def initialize
    start_leaderboard_fiber
  end

  def start_leaderboard_fiber
    puts "Leaderboard Fiber Started"
    spawn do
      loop do
        Fiber.yield
      end
    end
  end
end
