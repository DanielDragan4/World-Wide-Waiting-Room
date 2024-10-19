require "./worldwidewaitingroom"
require "redis"

class Powerup
  def initialize (@game : Game)

  end

  def get_name : String
    "Powerup"
  end

  def get_description (public_key) : String
    ""
  end

  def is_available_for_purchase (public_key) : Bool
    true
  end

  def is_stackable (public_key) : Bool
    false
  end

  def max_stack_size (public_key) : Int32
    0
  end

  def get_price (public_key) : Float64
    0.0
  end

  def get_player_stack_size (public_key) : Int32
    0
  end

  def buy_action (public_key) : String | Nil
    # Will get called upon purchase. If the return type is a String, it will be used as the error shown in the browser to the player.
  end

  def action (public_key, dt)
    # Will get called before the player's Time Units are updated
  end

  def cleanup (public_key)
    # Will get called after the player's Time Units are updated.
  end
end

class PowerupDoubleTime < Powerup
  def get_name
    "Double Time"
  end

  def get_description (public_key)
    "Doubles the number of units a player has. Can be used more than once."
  end

  def get_price (public_key)
    1000.0
  end

  def buy_action (public_key)
    puts "Purhcased double time!"

    @game.set_player_time_units public_key, (@game.get_player_time_units public_key) * 2
    @game.inc_time_units public_key, -1000

    nil
  end

  def action (public_key, dt)
  end
end

class PowerupBurstBoost < Powerup
  KEY = "burst_boost_stack"

  def get_name
    "Burst Boost"
  end

  def is_stackable
    false
  end

  def get_description(public_key)
    "Instantly gives 5000 units to a player. This is a one time use"
  end

  def get_price (public_key)
    is_renewed = get_player_last_used(public_key)

    if is_renewed
      return 1.0
    else
     return 999999999
    end
  end

  def max_stack_size (public_key)
    1
  end

  def get_unix
    current_time = Time.uts.to_unix
  end
  
  def get_player_last_used(public_key)
    if public_key

      current_unix = Time.utc.to_unix
      cooleddown_time = @game.get_key_value(public_key, KEY)
      if cooleddown_time.to_s.empty? 
        time = current_unix 
      else
        time = cooleddown_time.to_i
      end

      if current_unix >= time
        return true
      else
        return false
      end
    else
      nil
    end
  end

  def buy_action (public_key)

    if public_key
      is_renewed = get_player_last_used(public_key)

      if is_renewed
        puts "Purhcased Burst Boost!"

        @game.set_player_time_units public_key, (@game.get_player_time_units public_key) + 4999
        @game.set_key_value(public_key, KEY, (Time.utc.to_unix + 86400).to_s)
      else
        puts "Your out of Burst Boosts today :(. Come back tommorow for another!"
      end
    else
      nil
    end
    nil
  end

  def action (public_key, dt)
  end
end
