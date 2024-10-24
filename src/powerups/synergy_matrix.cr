require "../powerup.cr"

class PowerupSynergyMatrix < Powerup
  BASE_PRICE = 1000.0
  KEY = "synergy_matrix_stack"
  BOOST_PER_STACK = 0.10

  def self.get_stack_size(game : Game, public_key : String) : Int32
    if public_key
      size = game.get_key_value(public_key, KEY)
      size.to_s.empty? ? 0 : size.to_i
    else
      0
    end
  end

	#TODO: Implement a way for all powerups to be affected by multiplier value, and adjust when it changes
  def self.get_boost_multiplier(game : Game, public_key : String, powerup_id : String) : Float64
    return 1.0 if powerup_id == get_powerup_id # Prevents from boosting itself

    stack_size = get_stack_size(game, public_key)
    1.0 + (stack_size * BOOST_PER_STACK)
  end

  def self.get_powerup_id
    "synergy_matrix"
  end

  def get_name
    "Synergy Matrix"
  end

  def get_description(public_key)
    stack_size = get_player_stack_size(public_key)
    boost_percent = (stack_size * BOOST_PER_STACK * 100).to_i
    "Increases the effectiveness of all other powerups by 10%. The effect stacks additively with each purchase.\n Purchasing does not affect active powerups currently in use.
    Current boost: #{boost_percent}%"
  end

  def is_stackable
    true
  end

  def get_player_stack_size(public_key : String) : Int32
    self.class.get_stack_size(@game, public_key)
  end

  def get_price(public_key)
    stack_size = get_player_stack_size(public_key)
    BASE_PRICE * (1.5 ** stack_size)
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
end
