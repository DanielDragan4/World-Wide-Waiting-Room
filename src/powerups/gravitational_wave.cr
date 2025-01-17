require "../powerup"
require "big"
require "json"

class PowerupGravitationalWave < Powerup
  STACK_KEY = "gravitational_wave_stack"
  BASE_PRICE = BigFloat.new 0.0
  COOLDOWN_DURATION = 3#6 * 60 * 60
  GRAVITATIONAL_WAVE_COOLDOWN_KEY = "gravitational_wave_cooldown"
  EXPONENT = 2

  def category
    PowerupCategory::PASSIVE
  end

  def self.get_powerup_id
    "gravitational_wave"
  end

  def get_name
    "Gravatational Wave"
  end

  def get_description(public_key)
    "
    <strong>Duration:</strong> #{(COOLDOWN_DURATION/3600).round()} Hours<br>
    <strong>Stackable:</strong> Yes<br>
    <br>
    Increase Relatavistic Shift's boost exponentially and unit production in Unit Vault, but disables the use of Wormhole for 1.5 days. Only purchasable every 1.5 days."
  end

  def get_price (public_key)
    BASE_PRICE
  end

  def cooldown_seconds_left(public_key)
    @game.get_timer_seconds_left public_key, GRAVITATIONAL_WAVE_COOLDOWN_KEY
  end

  def is_available_for_purchase(public_key)
    timer = @game.is_timer_expired public_key, GRAVITATIONAL_WAVE_COOLDOWN_KEY

    return timer
  end

  def max_stack_size (public_key)
    5
  end

  def get_relativistic_shift_boost(public_key, base)
    stack_size = get_player_stack_size(public_key)

    if stack_size == 0
      return base
    end
    result = BigFloat.new(base)
  
    (1..stack_size).each do
      result = result ** EXPONENT
    end

    return result
  end

  def get_player_stack_size(public_key)
    @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 0.0)
  end

  def buy_action (public_key)
    if public_key
      if is_available_for_purchase(public_key)
        new_stack = get_player_stack_size(public_key) + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)
       
        @game.set_timer public_key, GRAVITATIONAL_WAVE_COOLDOWN_KEY, COOLDOWN_DURATION
      end

      else
        puts "Your Dont have Enough units Left"
      end
    nil
  end

  def action (public_key, dt)
  end

  def cleanup (public_key)
  end
end
