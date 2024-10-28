require "../powerup.cr"

class PowerupUnitMultiplier < Powerup
  BASE_PRICE = 1_000.0
  MULTIPLIER = 1.3
  KEY = "unit_multiplier_stack"

  def new_multiplier(public_key) : Float64
    (MULTIPLIER) * get_synergy_boosted_multiplier(public_key, 1.0)
  end

  def self.get_powerup_id
    "unit_multiplier"
  end

  def get_name
    "Unit Multiplier"
  end

  def get_description (public_key)
    adjusted_multiplier = new_multiplier(public_key)
    "Permanently increases unit production by #{((adjusted_multiplier - 1) * 100).round(2).floor}%. Price increases multiplicatively."
  end

  def is_stackable
    true
  end

  def get_price(public_key)
    stack_size = get_player_stack_size(public_key)
    (BASE_PRICE * (1.5 ** stack_size)).round(2)
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, KEY)
      size.to_s.empty? ? 0 : size.to_i
    else
      0
    end
  end

  def buy_action(public_key)
    if public_key
      price = get_price(public_key)
      units = @game.get_player_time_units(public_key)
      if units >= price
        current_stack = get_player_stack_size(public_key)
        powerup = PowerupUnitMultiplier.get_powerup_id
        
        @game.inc_time_units(public_key, -price)
        @game.add_powerup(public_key, powerup)

        new_stack = current_stack + 1
        @game.set_key_value(public_key, KEY, new_stack.to_s)

      else
        "You don't have enough units to purchase Unit Multiplier"
      end
    else
      nil
    end
  end

  def action(public_key, dt)
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && !(@game.has_powerup public_key, PowerupOverCharge.get_powerup_id) && @game.has_powerup public_key, AfflictPowerupBreach.get_powerup_id
      current_rate = @game.get_player_time_units_ps(public_key)
      stack_size = get_player_stack_size(public_key)
      adjusted_multiplier = new_multiplier(public_key)
      new_rate = current_rate * adjusted_multiplier ** stack_size
      @game.set_player_time_units_ps(public_key, new_rate)
    end
  end

  def cleanup(public_key)
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && !(@game.has_powerup public_key, PowerupOverCharge.get_powerup_id) && @game.has_powerup public_key, AfflictPowerupBreach.get_powerup_id
      current_rate = @game.get_player_time_units_ps(public_key)
      stack_size = get_player_stack_size(public_key)
      adjusted_multiplier = new_multiplier(public_key)
      new_rate = current_rate / adjusted_multiplier ** stack_size
      @game.set_player_time_units_ps(public_key, new_rate)
    end
  end
end
