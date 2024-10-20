require "../powerup.cr"

class PowerupUnitMultiplier < Powerup
  BASE_PRICE = 1000.0
  MULTIPLIER = 1.05
  KEY = "unit_multiplier_stack"

  def self.get_powerup_id
    "unit_multiplier"
  end

  def get_name
    "Unit Multiplier"
  end

  def get_description (public_key)
    "Permanently increases units/s by 5%. Can be purchased multiple times with escalating costs."
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
      if units > price
        current_stack = get_player_stack_size(public_key)
        price = get_price(public_key)

        @game.inc_time_units(public_key, -price)

        current_rate = @game.get_player_time_units_ps(public_key)
        new_rate = current_rate * (MULTIPLIER)
        @game.set_player_time_units_ps(public_key, new_rate)

        new_stack = current_stack + 1
        @game.set_key_value(public_key, KEY, new_stack.to_s)
      else
        "You don't have enough point to purchase Unit Multiplier"
      end
    else
      nil
    end
  end

  def action(public_key, dt)
  end
end
