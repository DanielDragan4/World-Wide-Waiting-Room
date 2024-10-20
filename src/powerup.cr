require "./worldwidewaitingroom"
require "redis"

class Powerup
  def initialize (@game : Game)

  end

  def self.get_powerup_id : String
    "powerup"
  end

  def get_name : String
    "Powerup"
  end

  def get_description (public_key : String) : String
    ""
  end

  def is_available_for_purchase (public_key : String) : Bool
    true
  end

  def is_stackable (public_key : String) : Bool
    false
  end

  def max_stack_size (public_key : String) : Int32
    0
  end

  def get_price (public_key : String) : Float64
    0.0
  end

  def cooldown_seconds_left (public_key : String) : Int32
    0
  end

  def get_player_stack_size (public_key : String) : Int32
    0
  end

  def buy_action (public_key : String) : String | Nil
    # Will get called upon purchase. If the return type is a String, it will be used as the error shown in the browser to the player.
  end

  def action (public_key : String, dt)
    # Will get called before the player's Time Units are updated
  end

  def cleanup (public_key : String)
    # Will get called after the player's Time Units are updated.
  end
end
