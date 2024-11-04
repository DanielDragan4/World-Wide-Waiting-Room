require "../powerup.cr"
require "./cosmic_breakthrough"

class PowerupUnitMultiplier < Powerup
  BASE_PRICE = 25.0
  BASE_AMOUNT = 1.0
  KEY = "unit_multiplier_stack"

  def category
    PowerupCategory::ACTIVE
  end

  def new_multiplier(public_key) : BigFloat
    prestige_multi = get_civ_boost(public_key)
    get_synergy_boosted_multiplier(public_key, prestige_multi)
  end

  def self.get_powerup_id
    "unit_multiplier"
  end

  def get_name
    "Unit Multiplier"
  end

  def get_description (public_key)
    adjusted_multiplier = new_multiplier(public_key)
    "Permanently increases unit production by #{(adjusted_multiplier).round(2)} with each purchase. Price increases multiplicatively. Number purchased: #{get_player_stack_size(public_key)}"
  end

  def is_stackable
    true
  end

  def get_price(public_key)
    stack_size = get_player_stack_size(public_key) + 1
    boost = get_civ_boost(public_key)
    multi = (boost/1.0)
    base_increase = (multi == 1) ? 1 : multi/2
    price = BigFloat.new ((BASE_PRICE * base_increase) * ( stack_size ** 1.75))
    price.round(2)
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, KEY)
      size.to_s.empty? ? 0 : size.to_i
    else
      0
    end
  end

  def get_civ_boost(public_key)
    PowerupCosmicBreak.get_unit_boost(public_key, KEY, BASE_AMOUNT)
  end

  def self.new_prestige(public_key, game : Game)
    game.set_key_value(public_key, KEY, (0).to_s)
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
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && !(@game.has_powerup public_key, PowerupOverCharge.get_powerup_id) && !@game.has_powerup public_key, AfflictPowerupBreach.get_powerup_id
      current_rate = @game.get_player_time_units_ps(public_key)
      stack_size = get_player_stack_size(public_key) + 1
      adjusted_multiplier = new_multiplier(public_key)

      rate_increase = current_rate * (adjusted_multiplier * stack_size) -current_rate
      @game.inc_time_units_ps(public_key, rate_increase)
    end
  end

  def cleanup(public_key)
  end
end
