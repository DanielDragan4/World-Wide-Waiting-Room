require "../powerup"
require "./afflict_antimatter.cr"

class PowerupAntimatter < Powerup
  BASE_PRICE = BigFloat.new 1_000_000
  TIMER_KEY = "antimatter_timer"
  DURATION = 2 * 60 *60

  def category
    PowerupCategory::SABOTAGE
  end

  def self.get_powerup_id
    "antimatter"
  end

  def is_input_powerup (public_key)
    true
  end

  def input_activates (public_key)
    AfflictPowerupAntimatter.get_powerup_id
  end

  def input_button_text (public_key)
    "Antimatter"
  end

  def get_name
    "Antimatter"
  end

  def get_description (public_key)
    multi = (get_synergy_boosted_multiplier public_key, BigFloat.new 1.0) -1
    reduced_multi = multi/10
    time = AfflictPowerupAntimatter::COOLDOWN * (1 + reduced_multi)

    "<strong>Duration:</strong> #{(time / 60).round(2)} Minutes<br>
    <strong>Stackable:</strong> No<br><br>
    Disables purchase of sabotage powerups for the selected player."
  end

  def cooldown_seconds_left(public_key)
    @game.get_timer_seconds_left public_key, TIMER_KEY
  end

  def get_price (public_key)
    price = BASE_PRICE * 2 ** (@game.get_powerup_stack public_key, PowerupAntimatter.get_powerup_id)
    alterations = @game.get_cached_alterations
    price = @game.increase_number_by_percentage price, BigFloat.new alterations.sabotage_price
    price.round 2
  end

  def is_available_for_purchase (public_key)
    if (@game.has_powerup public_key, PowerupAntimatter.get_powerup_id) || !(@game.is_timer_expired public_key, TIMER_KEY) || ((@game.get_player_time_units public_key) < (get_price public_key))
      return false
    end

    return true
  end

  def buy_action (public_key)
    if is_available_for_purchase public_key
      @game.add_powerup public_key, PowerupAntimatter.get_powerup_id
      @game.inc_time_units public_key, -(get_price public_key)
      @game.inc_powerup_stack public_key, PowerupAntimatter.get_powerup_id
      @game.set_timer public_key, TIMER_KEY, DURATION
    end
  end
end
