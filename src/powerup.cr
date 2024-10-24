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

  # base_multiplier assumes that only the value expected to be adjusted is entered.
  # ex1. For a 2x boost, base_multiplier = 2
  # ex2. For a 5% addition to current units/s, or 1.05x, base_multiplier = 0.05 (since only the 5% change should be affected).
  # Returns the new multiplier value after having Synergy Matrix boost applied.
  def get_synergy_boosted_multiplier(public_key : String, base_multiplier : Float64) : Float64
    synergy_boost = PowerupSynergyMatrix.get_boost_multiplier(@game, public_key, self.class.get_powerup_id)
    (base_multiplier) * synergy_boost
  end
end
