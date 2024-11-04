require "./worldwidewaitingroom"
require "redis"

alias PopupInfo = Hash(String, String | Float64 | Int64 | Int32 | Float32)

enum PowerupCategory
  PASSIVE
  DEFENSIVE
  ACTIVE
  SABATOGE
end

class Powerup
  def initialize (@game : Game)

  end

  def self.get_powerup_id : String
    "powerup"
  end

  def category : PowerupCategory
    PowerupCategory::PASSIVE
  end

  def get_popup_info (public_key : String) : PopupInfo
    Hash(String, String | Float64 | Int64 | Int32 | Float32).new
  end

  def player_card_powerup_active_css_class (public_key : String) : String
    ""
  end

  def player_card_powerup_icon (public_key : String) : String
    ""
  end

  def is_afflication_powerup (public_key : String) : Bool
    # An afflication "powerup" is a way to reuse the powerup system to implement the negative effects
    # of a powerup. For example, Signal Jammer when used will add the afflict_signal_jammer powerup
    # to a player which implements the negative features of that powerup.
    false
  end

  def is_achievement_powerup (public_key : String) : Bool
    # An achievement powerup is not purchasable but instead _unlockable_
    # Functionally, an achievement powerup has its action method run regardless of whether the player actually has the achievement unlocked or not
    # It is the powerup's job to handle the specific logic outside of that.
    false
  end

  def is_input_powerup (public_key : String) : Bool
    # An input powerup gives the player an action that can be performed once
    # another player card.
    false
  end

  def input_activates (public_key : String) : String
    # Returns the powerup ID of the powerup that gets activated
    # when the input button is pressed
    ""
  end

  def input_button_text (public_key : String) : String
    # The text shown on the input button.
    ""
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

  def get_price (public_key : String) : BigFloat
    BigFloat.new 0.0
  end

  def cooldown_seconds_left (public_key : String) : Int32
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
  def get_synergy_boosted_multiplier(public_key : String, base_multiplier : Float64) : BigFloat
    synergy = @game.get_powerup_classes[PowerupSynergyMatrix.get_powerup_id]
    synergy = synergy.as PowerupSynergyMatrix
    synergy_boost = synergy.get_boost_multiplier(public_key)
    BigFloat.new base_multiplier * BigFloat.new synergy_boost
  end
end
