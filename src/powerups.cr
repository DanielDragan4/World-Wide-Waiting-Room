require "./worldwidewaitingroom"
require "redis"

class Powerup
  def initialize (@game : Game)

  end

  def get_name : String
    "Powerup"
  end

  def get_description : String
    ""
  end

  def is_available_for_purchase : Bool
    true
  end

  def is_stackable : Bool
    false
  end

  def max_stack_size : Int32
    0
  end

  def get_price : Float64
    0.0
  end

  def get_player_stack_size (public_key) : Int32
    0
  end

  def buy_action (public_key)
    # Will get called upon purchase
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

  def get_description
    "Doubles the number of units a player has. Can be used more than once."
  end

  def get_price
    1000.0
  end

  def action (public_key, dt)
    puts "Ran double time!"

    @game.set_player_time_units public_key, (@game.get_player_time_units public_key) * 2
    @game.remove_powerup public_key, Powerups::DOUBLE_TIME
  end
end
