require "../powerup.cr"
require "./unit_multiplier"
require "./synergy_matrix"


class PowerupCosmicBreak < Powerup
  BASE_PRICE = 150_000_000.0
  KEY = "cosmic_break_stack"
  SYNERGY_VALUES = [1.0, 2.5, 5.0, 10.0, 25.0, 40.0, 100.0]
  UNIT_VALUES = [1.0, 5.0, 20.0, 50.0, 100.0, 150.0, 500.0]

  def get_stack_size(public_key : String) : Int32
    size = @game.get_key_value(public_key, KEY)
    size.to_s.empty? ? 0 : size.to_i
  end

  def get_unit_boost(public_key : String, base_amount : Float64) : Float64
    
    stack_size = get_stack_size(public_key)
    unit_boost = UNIT_VALUES[stack_size] * base_amount

    unit_boost
  end

  def get_synergy_boost(public_key : String, base_amount : Float64) : Float64

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
    "Resets Unit Multiplyer and Synergy Matrix to 0 but increase their base rate by some multiple. Current Civilization Type: #{stack_size} | Next Synergy Precent: #{SYNERGY_VALUES[stack_size+1]*10}% | Next Unit Multiplyer Rate: #{UNIT_VALUES[stack_size+1]}"
  end

  def category
    PowerupCategory::PASSIVE
  end

  def get_price(public_key)
    stack_size = get_stack_size(public_key) + 1
    price = BASE_PRICE * ((stack_size) **(2 + (stack_size ** 1.75)))
    BigFloat.new price
  end

  def buy_action(public_key)
    puts "Purchasing Cosmic Breakthrough"
    if public_key
      price = get_price(public_key)
      units = @game.get_player_time_units(public_key)

      if units > price
        current_stack = get_stack_size(public_key)
        new_stack = current_stack + 1

        @game.inc_time_units(public_key, -price)
        @game.set_key_value(public_key, KEY, new_stack.to_s)
        @game.add_powerup(public_key, PowerupCosmicBreak.get_powerup_id)

        synergy = @game.get_powerup_classes[PowerupSynergyMatrix.get_powerup_id]
        unit = @game.get_powerup_classes[PowerupUnitMultiplier.get_powerup_id]
        synergy = synergy.as PowerupSynergyMatrix
        unit = unit.as PowerupUnitMultiplier

        synergy.new_prestige(public_key, @game)
        unit.new_prestige(public_key, @game)
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