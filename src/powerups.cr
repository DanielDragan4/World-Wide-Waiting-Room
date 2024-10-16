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
