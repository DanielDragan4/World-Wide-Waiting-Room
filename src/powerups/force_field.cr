require "../powerup"
require "./force_field.cr"

require "../worldwidewaitingroom.cr"

class PowerupForceField < Powerup
  BASE_PRICE = 10_000_000
  COOLDOWN = 60 * 60
  COOLDOWN_KEY = "forcefield_cooldown_time"

  def self.get_powerup_id
    "forcefield"
  end

  def player_card_powerup_active_css_class (public_key)
    "border border-rounded border-[10px] border-blue-600"
  end

  def get_name
    "Force Field"
  end

  def get_description (public_key)
    "Blocks all sabotoge effects for 1 hour. Can be used every 3 hours"
  end

  def get_price (public_key)
    BASE_PRICE
  end

  def is_available_for_purchase (public_key)
    if (@game.has_powerup public_key, PowerupForceField.get_powerup_id)
      return false
    end

    if (@game.get_player_time_units public_key) < (get_price public_key)
      return false
    end

    return true
  end

  def cooldown_seconds_left (public_key)
    @game.get_timer_seconds_left public_key, COOLDOWN_KEY
  end

  def buy_action (public_key)
    if !is_available_for_purchase public_key
      return "Not available for purchase."
    end

    @game.add_powerup public_key, PowerupForceField.get_powerup_id
    @game.set_timer public_key, COOLDOWN_KEY, COOLDOWN
  end

  def cleanup (public_key)
    if @game.is_timer_expired public_key, COOLDOWN_KEY
      @game.remove_powerup public_key, PowerupForceField.get_powerup_id
    end
  end
end
