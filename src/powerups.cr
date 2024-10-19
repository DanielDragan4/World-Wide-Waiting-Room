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
    1.0
  end

  def buy_action (public_key)
    puts "Purhcased double time!"

    @game.set_player_time_units public_key, (@game.get_player_time_units public_key) * 2
    @game.inc_time_units public_key, -1

    nil
  end

  def action (public_key, dt)
  end
end

class PowerupBootStrap < Powerup
  STACK_KEY = "bootstrap_stack"
  COOLDOWN_KEY = "bootstrap_cooldown"
  BASEPRICE = 5000
  BASEBURST = 0.05

  def get_name
    "BootStrap"
  end

  def is_stackable
    true
  end

  def get_description(public_key)
    "Gives 5% of total units Increasing multiplictivly with each purchase. Can only be purchased once every 24 hours. Cost of 10% of your total units.\nNext Amount Earned: #{(1 + (BASEBURST * get_player_stack_size(public_key)))}x points"
  end

  def get_price (public_key)
    price = BASEPRICE + ((@game.get_player_time_units public_key) * 0.1)
  end

  def max_stack_size (public_key)
    7.0
  end
  
  def is_available_for_purchase(public_key)
    if public_key
      cooldown = @game.get_player_cooldown(public_key, COOLDOWN_KEY)

      return cooldown
    else
      false
    end
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, STACK_KEY)
      size.to_s.empty? ? 1 : size.to_i
    else
      1
    end
  end 

  def get_unix
    current_time = Time.uts.to_unix
  end

  def buy_action (public_key)

    if public_key
      if is_available_for_purchase(public_key)

        current_stack = get_player_stack_size(public_key)

        puts "Purhcased Burst Boost!"
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) * 0.9)
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) * (1 + (BASEBURST * current_stack)))
        @game.set_key_value(public_key, COOLDOWN_KEY, (Time.utc.to_unix + 86400).to_s)

        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)
      else
        puts "Your out of BootStraps today :(. Come back tommorow for another!"
      end
    else
      nil
    end
    nil
  end

  def action (public_key, dt)
  end
end
