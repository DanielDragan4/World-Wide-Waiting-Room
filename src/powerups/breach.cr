require "../powerup"
require "./afflict_breach.cr"

class PowerupBreach < Powerup
  BASE_PRICE = 3_000_000

  def self.get_powerup_id
    "breach"
  end

  def is_input_powerup (public_key)
    true
  end

  def input_activates (public_key)
    AfflictPowerupBreach.get_powerup_id
  end

  def input_button_text (public_key)
    "Breach"
  end

  def get_name
    "Breach"
  end

  def get_description (public_key)
    "Disabled all of a player's passive powerups for 10 minutes."
  end

  def get_price (public_key)
    BASE_PRICE
  end

  def is_available_for_purchase (public_key)
    if (@game.has_powerup public_key, PowerupBreach.get_powerup_id)
      return false
    end

    if (@game.get_player_time_units public_key) < (get_price public_key)
      return false
    end

    return true
  end

  def buy_action (public_key)
    if !is_available_for_purchase public_key
      return "Not available for purchase."
    end

    @game.add_powerup public_key, PowerupBreach.get_powerup_id
  end
end
