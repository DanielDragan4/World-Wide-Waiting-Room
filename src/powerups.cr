require "./worldwidewaitingroom"
require "redis"

class Powerup
  def initialize (@game : Game)

  end

  def get_name : String
    "Powerup"
  end

  def get_description (public_key) : String
    ""
  end

  def is_available_for_purchase (public_key) : Bool
    true
  end

  def is_stackable (public_key) : Bool
    false
  end

  def max_stack_size (public_key) : Int32
    0
  end

  def get_price (public_key) : Float64
    0.0
  end

  def get_player_stack_size (public_key) : Int32
    0
  end

  def buy_action (public_key) : String | Nil
    # Will get called upon purchase. If the return type is a String, it will be used as the error shown in the browser to the player.
  end

  def action (public_key, dt)
    # Will get called before the player's Time Units are updated
  end

  def cleanup (public_key)
    # Will get called after the player's Time Units are updated.
  end
end

class PowerupDoubleTime < Powerup
  def get_name
    "Double Time"
  end

  def get_description (public_key)
    "Doubles the number of units a player has. Can be used more than once."
  end

  def get_price (public_key)
    1000.0
  end

  def buy_action (public_key)
    puts "Purhcased double time!"

    @game.set_player_time_units public_key, (@game.get_player_time_units public_key) * 2
    @game.inc_time_units public_key, -1000

    nil
  end

  def action (public_key, dt)
  end
end

class PowerupUnitMultiplier < Powerup
  BASE_PRICE = 10.0
  MULTIPLIER = 1.05
  KEY = "unit_multiplier_stack"

  def get_name
    "Unit Multiplier"
  end

  def get_description (public_key)
    "Permanently increases units/s by 5%. Can be purchased multiple times with escalating costs.\nCurrent Multiplier: #{@game.get_player_time_units_ps(public_key)}x"
  end

  def is_stackable
    true
  end

  def get_price(public_key)
    stack_size = get_player_stack_size(public_key)
    BASE_PRICE * (1.5 ** stack_size)
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
      current_stack = get_player_stack_size(public_key)
      price = get_price(public_key)

      @game.inc_time_units(public_key, -price)
      
      current_rate = @game.get_player_time_units_ps(public_key)
      new_rate = current_rate * (MULTIPLIER)
      @game.set_player_time_units_ps(public_key, new_rate)

      new_stack = current_stack + 1
      @game.set_key_value(public_key, KEY, new_stack.to_s)
    else
      nil
    end
  end

  def action(public_key, dt)
  end
end