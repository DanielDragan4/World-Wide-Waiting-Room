require "../powerup"
require "./afflict_signal_jammer.cr"

class PowerupSignalJammer < Powerup
  BASE_PRICE = 2_000

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
    time = get_synergy_boosted_multiplier public_key, AfflictPowerupSignalJammer::COOLDOWN
    "Reduce a target player's unit production by 50% for #{time / 60} minutes. The price increases multiplicatively."
  end

  def get_price (public_key)
    mult = ((@game.get_powerup_stack public_key, PowerupSignalJammer.get_powerup_id) * 5)
    price = BASE_PRICE * (mult == 0 ? 1 : mult)
    BigFloat.new price
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

  def buy_action (public_key)
    if is_available_for_purchase public_key
      @game.add_powerup public_key, PowerupSignalJammer.get_powerup_id
      @game.inc_time_units public_key, -(get_price public_key)
      @game.inc_powerup_stack public_key, PowerupSignalJammer.get_powerup_id
    end
  end
end
