require "../powerup"

class PowerupForceField < Powerup
  BASE_PRICE = 10_000_000

  def self.get_powerup_id
    "forcefield"
  end

  def get_name
    "Force Field"
  end

  def get_description (public_key)
    "Blocks all sabotoge effects for 1 hour."
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

  def buy_action (public_key)
    if !is_available_for_purchase public_key
      return "Not available for purchase."
    end

    @game.add_powerup public_key, PowerupForceField.get_powerup_id
  end
end
