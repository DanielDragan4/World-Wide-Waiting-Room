require "../powerup.cr"
require "./cosmic_breakthrough"

class PowerupSynergyMatrix < Powerup
  BASE_PRICE = BigFloat.new 50.0
  BASE_AMOUNT = BigFloat.new 0.1
  KEY = "synergy_matrix_stack"

  def category
    PowerupCategory::PASSIVE
  end

  def get_boost_multiplier(public_key : String) : BigFloat
    synergy = @game.get_powerup_classes[PowerupSynergyMatrix.get_powerup_id]
    synergy = synergy.as PowerupSynergyMatrix
    stack_size = synergy.get_player_stack_size(public_key)
    boost = synergy.get_civ_boost(public_key)
    1.0 + (stack_size * boost)
  end

  def self.get_powerup_id
    "synergy_matrix"
  end

  def get_name
    "Synergy Matrix"
  end

  def get_description(public_key)
    stack_size = get_player_stack_size(public_key)
    boost = get_civ_boost(public_key)
    boost_percent = (stack_size * boost * 100)
    "Increases the effectiveness of all other powerups by #{(boost * 100).round}%. The effect stacks additively with each purchase.\n Purchasing does not affect active powerups currently in use.
    <br>Current boost: #{boost_percent.round}%"
  end

  def is_stackable
    true
  end

  def get_player_stack_size(public_key : String)
    @game.get_key_value_as_int(public_key, KEY, BigInt.new 0)
  end

  def get_price(public_key)
    stack_size = get_player_stack_size(public_key) + 1
    boost = get_civ_boost(public_key)
    multi = (boost/0.1)
    base_increase = (multi == 1) ? 1 : multi/2
    BASE_PRICE * base_increase * ((stack_size) **(5 +(stack_size * (BigFloat.new 0.2))))
  end

  def get_civ_boost(public_key)
    breakthrough = @game.get_powerup_classes[PowerupCosmicBreak.get_powerup_id]
    breakthrough = breakthrough.as PowerupCosmicBreak
    breakthrough.get_synergy_boost(public_key, BASE_AMOUNT)
  end

  def new_prestige(public_key, game : Game)
    game.set_key_value(public_key, KEY, (0).to_s)
  end

  def buy_action(public_key)
    puts "Purchasing Synergy Matrix"
    if public_key
      price = get_price(public_key)
      units = @game.get_player_time_units(public_key)

      if units > price
        current_stack = get_player_stack_size(public_key)
        new_stack = current_stack + 1

        @game.inc_time_units(public_key, -price)
        @game.set_key_value(public_key, KEY, new_stack.to_s)
        @game.add_powerup(public_key, PowerupSynergyMatrix.get_powerup_id)
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
