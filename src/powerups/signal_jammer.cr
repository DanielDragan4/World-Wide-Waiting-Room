require "../powerup"
require "./afflict_signal_jammer.cr"
require "./afflict_antimatter.cr"
require "./force_field.cr"

class PowerupSignalJammer < Powerup
  BASE_PRICE = BigFloat.new 2_000

  def self.get_powerup_id
    "signal_jammer"
  end

  def category
    PowerupCategory::SABOTAGE
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
    multi = (get_synergy_boosted_multiplier public_key, BigFloat.new 1.0) -1
    reduced_multi = multi/10
    time = AfflictPowerupSignalJammer::COOLDOWN * (1 + reduced_multi)
    "<strong>Duration:</strong> #{(time/60).round} minutes<br><strong>Stackable:</strong> No<br><strong>Toggleable:</strong> No<br><br>Temporarily <b>halves</b> a selected player's Units/s."
  end

  def get_price (public_key)
    mult = ((@game.get_powerup_stack public_key, PowerupSignalJammer.get_powerup_id) * 5)
    price = BASE_PRICE * (mult == 0 ? 1 : mult)
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage price, BigFloat.new alterations.sabotage_price
  end

  def is_available_for_purchase (public_key)
    if (@game.has_powerup public_key, PowerupSignalJammer.get_powerup_id) || ((@game.has_powerup public_key, AfflictPowerupAntimatter.get_powerup_id) && !(@game.has_powerup public_key, PowerupForceField.get_powerup_id))
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
