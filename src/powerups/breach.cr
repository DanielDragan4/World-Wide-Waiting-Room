require "../powerup"
require "./afflict_breach.cr"

class PowerupBreach < Powerup
  BASE_PRICE = 3_000

  def category
    PowerupCategory::SABATOGE
  end

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
    time = get_synergy_boosted_multiplier public_key, BigFloat.new AfflictPowerupBreach::COOLDOWN
    "Disabled all of a player's passive powerups for #{time / 60} minutes. Price increases exponentially."
  end

  def get_price (public_key)
    price = BASE_PRICE * 2 ** (@game.get_powerup_stack public_key, PowerupBreach.get_powerup_id)
    (BigFloat.new price).round 2
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
    if is_available_for_purchase public_key
      @game.add_powerup public_key, PowerupBreach.get_powerup_id
      @game.inc_time_units public_key, -(get_price public_key)
      @game.inc_powerup_stack public_key, PowerupBreach.get_powerup_id
    end
  end
end
