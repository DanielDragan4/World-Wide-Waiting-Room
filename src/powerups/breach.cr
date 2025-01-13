require "../powerup"
require "./afflict_breach.cr"

class PowerupBreach < Powerup
  BASE_PRICE = BigFloat.new 3_000

  def category
    PowerupCategory::SABOTAGE
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
    "Hull Breach"
  end

  def get_name
    "Hull Breach"
  end

  def get_description (public_key)
    multi = (get_synergy_boosted_multiplier public_key, BigFloat.new 1.0) -1
    reduced_multi = multi/10
    time = AfflictPowerupBreach::COOLDOWN * (1 + reduced_multi)

    "<strong>Duration:</strong> #{(time / 60).round(2)} minutes<br>
    <strong>Stackable:</strong> No<br>
    <strong>Toggleable:</strong> No<br>
    <br>
    Temporarily disables all of a player's <b>Passive powerups</b>."
  end

  def get_price (public_key)
    price = BASE_PRICE * 2 ** (@game.get_powerup_stack public_key, PowerupBreach.get_powerup_id)
    alterations = @game.get_cached_alterations
    price = @game.increase_number_by_percentage price, BigFloat.new alterations.sabotage_price
    price.round 2
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
