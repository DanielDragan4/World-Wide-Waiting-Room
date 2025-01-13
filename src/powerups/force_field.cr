require "../powerup"
require "./force_field.cr"

require "../worldwidewaitingroom.cr"

class PowerupForceField < Powerup
  BASE_PRICE = BigFloat.new 10_000
  COOLDOWN = 60 * 60
  PRICE_MULTIPLIER = BigFloat.new 1.3
  NEXT_USE_COOLDOWN = 60 * 60 * 3
  NEXT_USE_COOLDOWN_KEY = "forcefield_next_use_cooldown"
  COOLDOWN_KEY = "forcefield_cooldown_time"

  def category
    PowerupCategory::DEFENSIVE
  end

  def self.get_powerup_id
    "forcefield"
  end

  def player_card_powerup_icon (public_key)
    "/forcefield.png"
  end

  def get_name
    "Force Field"
  end

  def get_popup_info (public_key) : PopupInfo
    pi = PopupInfo.new
    pi["Time Left"] = (@game.get_timer_time_left public_key, COOLDOWN_KEY)
    pi
  end

  def get_description (public_key)
    "<strong>Duration:</strong> #{(get_cooldown_time(public_key)/3600).round} Hour(s)<br><strong>Stackable:</strong> No<br><strong>Toggleable:</strong> No<br>Protects you from all sabotage effects (current and future)"
  end

  def get_cooldown_time(public_key)
    multi = (get_synergy_boosted_multiplier public_key, BigFloat.new 1.0) -1
    reduced_multi = multi/10

    COOLDOWN * (1 + reduced_multi)
  end

  def get_next_use_cooldown (public_key)
    multi = (get_synergy_boosted_multiplier public_key, BigFloat.new 1.0) -1
    reduced_multi = multi/10

    NEXT_USE_COOLDOWN * (1 + reduced_multi)
  end

  def get_price (public_key)
    alterations = @game.get_cached_alterations
    stack_size = @game.get_powerup_stack public_key, PowerupForceField.get_powerup_id
    price = stack_size == 0 ? BASE_PRICE : BASE_PRICE * (PRICE_MULTIPLIER * stack_size)
    @game.increase_number_by_percentage price, BigFloat.new alterations.defensive_price
  end

  def is_available_for_purchase (public_key)
    if (@game.has_powerup public_key, PowerupForceField.get_powerup_id)
      return false
    end

    if (@game.get_player_time_units public_key) < (get_price public_key)
      return false
    end

    if !(@game.is_timer_expired public_key, NEXT_USE_COOLDOWN_KEY)
      return false
    end

    return true
  end

  def cooldown_seconds_left (public_key)
    @game.get_timer_seconds_left public_key, NEXT_USE_COOLDOWN_KEY
  end

  def buy_action (public_key)
    if !is_available_for_purchase public_key
      return "Not available for purchase."
    end

    @game.inc_time_units public_key, -(get_price public_key)
    @game.add_powerup public_key, PowerupForceField.get_powerup_id
    @game.set_timer public_key, COOLDOWN_KEY, (get_cooldown_time(public_key)).to_i
    @game.set_timer public_key, NEXT_USE_COOLDOWN_KEY, (get_next_use_cooldown(public_key)).to_i
    @game.inc_powerup_stack public_key, PowerupForceField.get_powerup_id
  end

  def cleanup (public_key)
    @game.remove_powerup_if_timer_expired public_key, COOLDOWN_KEY, PowerupForceField.get_powerup_id
  end
end
