require "../powerup.cr"
require "./unit_multiplier"
require "./synergy_matrix"


class PowerupCosmicBreak < Powerup
  BASE_PRICE = 50_000_000.0
  KEY = "cosmic_break_stack"
  SYNERGY_VALUES = [1.0, 2.5, 4.0, 6.0, 8.0, 10.0]
  UNIT_VALUES = [1.0, 5.0, 15.0, 30.0, 50.0, 75.0]

  def get_stack_size(public_key : String) : BigInt
    @game.get_key_value_as_int(public_key, KEY, BigInt.new 0)
  end

  def get_unit_boost(public_key : String, base_amount : BigFloat) : BigFloat

    stack_size = get_stack_size(public_key)
    unit_boost = UNIT_VALUES[stack_size] * base_amount

    unit_boost
  end

  def get_synergy_boost(public_key : String, base_amount : BigFloat) : BigFloat

    stack_size = get_stack_size(public_key)
    synergy_boost = SYNERGY_VALUES[stack_size] * base_amount

    synergy_boost
  end

  def self.get_powerup_id
    "cosmic_breakthrough"
  end

  def get_name
    "Cosmic Breakthrough"
  end

  def get_description(public_key)
    stack_size = get_stack_size(public_key)
    "Resets Unit Multiplyer, Synergy Matrix, Automation Upgrade, and Tedious Gains to 0 but increase their base rate by some multiple. Current Civilization Type: #{stack_size} | Next Synergy Precent: #{SYNERGY_VALUES[stack_size+1]*10}% | Next Unit Multiplyer Rate: #{UNIT_VALUES[stack_size+1]}"
  end

  def category
    PowerupCategory::PASSIVE
  end

  def get_price(public_key)
    stack_size = get_stack_size(public_key) + 1
    price = BASE_PRICE * ((stack_size) **(3 + (stack_size ** 2.25)))
    BigFloat.new price
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)
    units = @game.get_player_time_units(public_key)
    stack_size = get_stack_size(public_key)

    available = (units > price) && (stack_size < 5)
    available
  end

  def buy_action(public_key)
    puts "Purchasing Cosmic Breakthrough"
    if public_key
      price = get_price(public_key)

      if is_available_for_purchase(public_key)
        current_stack = get_stack_size(public_key)
        new_stack = current_stack + 1

        @game.inc_time_units(public_key, -price)
        @game.set_key_value(public_key, KEY, new_stack.to_s)
        @game.add_powerup(public_key, PowerupCosmicBreak.get_powerup_id)

        synergy = @game.get_powerup_classes[PowerupSynergyMatrix.get_powerup_id]
        unit = @game.get_powerup_classes[PowerupUnitMultiplier.get_powerup_id]
        automation = @game.get_powerup_classes[PowerupAutomationUpgrade.get_powerup_id]
        tedious = @game.get_powerup_classes[PowerupTediousGains.get_powerup_id]

        synergy = synergy.as PowerupSynergyMatrix
        unit = unit.as PowerupUnitMultiplier
        automation = automation.as PowerupAutomationUpgrade
        tedious = tedious.as PowerupTediousGains

        synergy.new_prestige(public_key, @game)
        unit.new_prestige(public_key, @game)
        automation.new_prestige(public_key, @game)
        tedious.new_prestige(public_key, @game)
      else
        return "Not enough time units"
      end
    end
  end

  def action(public_key, dt)
  end

  def cleanup(public_key)
  end
end
