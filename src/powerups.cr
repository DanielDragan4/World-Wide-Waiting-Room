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
      1.0
    else
      max_value = Int32::MAX
    end
  end

  def max_stack_size (public_key)
    1
  end

  def get_current_utc
    current_time = Time.utc
  end
  
  def get_player_last_used(public_key)
    if public_key
      time_string = @game.get_key_value(public_key, KEY)
      if time_string.nil? 
        return true
      else
        time = Time.parse!(time_string, "%Y-%m-%d %H:%M:%S %z")
      
        if (time + 1.day) >= get_current_utc()
          return true
        else
          false
        end
        end
    else
      false
    end
  end

  def buy_action (public_key)

    if public_key
      is_renewed = get_player_last_used(public_key)

      if is_renewed
        puts "Purhcased Burst Boost!"

        current_utc = get_current_utc()

        @game.set_player_time_units public_key, (@game.get_player_time_units public_key) + 4999
        @game.set_key_value(public_key, KEY, current_utc.to_s("%Y-%m-%d %H:%M:%S %:z"))
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
