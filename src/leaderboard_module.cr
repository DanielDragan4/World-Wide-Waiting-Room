require "./modules"

class LeaderboardModule
  getter leaderboard

  def initialize
    @leaderboard = Array(Tuple(String, WaiterTup)).new
    @place = Hash(String, Int64).new
  end

  def compute
    @leaderboard.clear
    @place.clear

    Modules::Waiters.waiters.each do | uid, waiter |
      @leaderboard << { uid, waiter.serialize }
    end

    @leaderboard = @leaderboard.sort { | a, b | b[1][1] <=> a[1][1] }
    @leaderboard.each_with_index do | value, index |
      @place[value[0]] = index + 1
    end

    Modules::GlobalTimer.emit
  end

  def get_place (uid)
    @place.fetch uid, nil
  end
end
