require "../powerup"
require "./afflict_signal_jammer.cr"

class PowerupSignalJammer < Powerup
  BASE_PRICE = 1_000_000
  COOLDOWN = 60 * 60 * 24
  KEY_COOLDOWN = "signal_jammer_cooldown"

  def self.get_powerup_id
    "signal_jammer"
  end

  def is_input_powerup (public_key)
    true
  end

  def input_button_text (public_key)
    "Jam"
  end

  def input_activates (public_key)
    AfflictPowerupSignalJammer.get_powerup_id
  end

  def get_name
    "Signal Jammer"
  end

  def get_description (public_key)
    "Reduce a target player's units/s by 50% for 10 minutes. This powerup can be used once every 24 hours."
  end

  def get_price (public_key)
    BASE_PRICE
  end

  def is_available_for_purchase (public_key)
    if (@game.has_powerup public_key, PowerupSignalJammer.get_powerup_id)
      return false
    end

    if (@game.get_player_time_units public_key) < (get_price public_key)
      return false
    end

    return true
  end

  def cooldown_seconds_left (public_key)
    cd = @game.get_key_value_as_float public_key, KEY_COOLDOWN
    cd ||= 0
    cd - @game.ts
  end

  def buy_action (public_key)
    if !is_available_for_purchase public_key
      return "Not available for purchase."
    end

    @game.add_powerup public_key, PowerupSignalJammer.get_powerup_id
    @game.set_key_value public_key, KEY_COOLDOWN, (@game.ts + COOLDOWN).to_s
  end
end
