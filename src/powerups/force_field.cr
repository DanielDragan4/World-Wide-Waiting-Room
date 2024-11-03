require "../powerup"
require "./force_field.cr"

require "../worldwidewaitingroom.cr"

class PowerupForceField < Powerup
  BASE_PRICE = 10_000
  COOLDOWN = 60 * 60
  PRICE_MULTIPLIER = 1.3
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
    pi["Time Left"] = (@game.get_timer_seconds_left public_key, COOLDOWN_KEY)
    pi
  end

  def get_description (public_key)
    "Blocks all sabotoge effects for 1 hour. Can be used every 3 hours. The price is increased multiplicatively with each purchase."
  end

  def get_price (public_key)
    stack_size = @game.get_powerup_stack public_key, PowerupForceField.get_powerup_id
    price = stack_size == 0 ? BASE_PRICE : BASE_PRICE * (PRICE_MULTIPLIER * stack_size)
    BigFloat.new price
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
    @game.set_timer public_key, COOLDOWN_KEY, COOLDOWN
    @game.set_timer public_key, NEXT_USE_COOLDOWN_KEY, NEXT_USE_COOLDOWN
    @game.inc_powerup_stack public_key, PowerupForceField.get_powerup_id
  end

  def cleanup (public_key)
    @game.remove_powerup_if_timer_expired public_key, COOLDOWN_KEY, PowerupForceField.get_powerup_id
  end
end
