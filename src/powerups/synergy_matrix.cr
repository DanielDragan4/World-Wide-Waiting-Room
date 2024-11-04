require "../powerup.cr"

class PowerupSynergyMatrix < Powerup
  BASE_PRICE = 500.0
  BASE_AMOUNT = 0.1
  KEY = "synergy_matrix_stack"

  def category
    PowerupCategory::PASSIVE
  end

  def self.get_stack_size(game : Game, public_key : String) : Int32
    if public_key
      size = game.get_key_value(public_key, KEY)
      size.to_s.empty? ? 0 : size.to_i
    else
      0
    end
  end

  def self.get_boost_multiplier(game : Game, public_key : String, powerup_id : String) : Float64
    return 1.0 if powerup_id == get_powerup_id # Prevents from boosting itself

    stack_size = get_stack_size(game, public_key)
    boost = get_civ_boost(public_key, game)
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
    boost = get_civ_boost(public_key, @game)
    boost_percent = (stack_size * boost * 100).to_i
    "Increases the effectiveness of all other powerups by #{boost* 100}%. The effect stacks additively with each purchase.\n Purchasing does not affect active powerups currently in use.
    Current boost: #{boost_percent}%"
  end

  def is_stackable
    true
  end

  def get_player_stack_size(public_key : String) : Int32
    self.class.get_stack_size(@game, public_key)
  end

  def get_price(public_key)
    stack_size = get_player_stack_size(public_key) + 1
    boost = get_civ_boost(public_key, @game)
    multi = (boost/0.1)
    base_increase = (multi == 1) ? 1 : multi/2
    price = BASE_PRICE * base_increase * ((stack_size) **(5 +(stack_size * 0.2)))
    BigFloat.new price
  end

  def self.get_civ_boost(public_key, game : Game)
    Powerup.get_civilization_type_synergy(public_key, BASE_AMOUNT, game)
  end
  def get_civ_boost(public_key, game : Game)
    Powerup.get_civilization_type_synergy(public_key, BASE_AMOUNT, game)
  end

  def self.new_prestige(public_key, game : Game)
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
