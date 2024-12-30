require "../powerup"
require "json"
require "./force_field.cr"
require "math"

class PowerupParasite < Powerup
  BASE_PRICE = BigFloat.new 10#_000
  NEXT_TAKE_COOLDOWN = 1
  DURATION = 60 * 10

  PERCENTAGE_STEAL = BigFloat.new 0.2
  PRICE_MULTIPLIER = BigFloat.new 1.3

  KEY_DURATION = "parasite_duration"
  KEY_NEXT_TAKE_COOLDOWN = "parasite_next_take"
  KEY_ACTIVE_STACK = "parasite_active_stack"
  INITIAL_RATE = BigFloat.new 5e-3
  GROWTH_KEY = "growth_key"

  def new_percentage_steal(public_key)
    rate = 0.20
    new_rate = get_synergy_boosted_multiplier public_key, (PERCENTAGE_STEAL) * (get_active_parasite_stack public_key)

    if new_rate < 0.36
      rate = 0.30
    elsif new_rate < 0.45
      rate = 0.375
    elsif new_rate < 0.52
      rate = 0.425
    elsif new_rate < 0.6
      rate = 0.46
    elsif new_rate < 0.77
      rate = 0.485
    elsif new_rate < 0.84
      rate = 0.50
    elsif new_rate < 0.92
      rate = 0.51
    elsif new_rate < 1
      rate = 0.60
    elsif new_rate < 1.4
      rate = 0.65
    elsif new_rate < 2
      rate = 0.69
    elsif new_rate < 3
      rate = 0.72
    elsif new_rate < 4
      rate = 0.74
    elsif new_rate < 6
      rate = 0.82
    elsif new_rate < 10
      rate = 0.87
    elsif new_rate < 15
      rate = 0.91

    elsif new_rate < 20
      rate = 0.95
    else
      rate
    end
  end

  def category
    PowerupCategory::SABATOGE
  end

  def self.get_powerup_id
    "parasite"
  end

  def get_popup_info (public_key) : PopupInfo
    pi = PopupInfo.new
    pi["Timer Left"] = (@game.get_timer_seconds_left public_key, KEY_DURATION)
    pi["Parasite Stack"] = (get_active_parasite_stack public_key).to_s
    pi
  end

  def get_name
    "Parasite"
  end

  def player_card_powerup_icon (public_key)
    "/parasite.png"
  end

  def get_description (public_key)
    "Over the course of #{(DURATION / 60).to_i} minutes, steal a fraction of the units from the player directly ahead of you and directly behind you. The price is increased multiplicatively with each purchase. The number of active parasites can be stacked increasing the steal amount. Stacking parasites does not reset the 10 minute timer."
  end

  def calculate_growth_rate(public_key)
    lower = BigFloat.new(0.0)
    upper = BigFloat.new(1.0)
    tolerance = BigFloat.new(1e-10)
    max_iterations = 100
    steal = new_percentage_steal(public_key)
    
    max_iterations.times do
      r = (lower + upper) / 2
      
      begin
        log_sum = Math.log(INITIAL_RATE) + Math.log((Math.exp(r * DURATION) - 1) / (Math.exp(r) - 1))
        total = Math.exp(log_sum)
        
        if (total - steal).abs < tolerance
          @game.set_key_value public_key, GROWTH_KEY, r.to_s
        end
        
        if total < steal
          lower = r
        else
          upper = r
        end
      rescue
        upper = r 
      end
    end
      @game.set_key_value public_key, GROWTH_KEY, ((lower + upper) / 2).to_s
  end

  def steal_rate_at(time, public_key) : BigFloat
    growth_val = BigFloat.new(@game.get_key_value_as_float public_key, GROWTH_KEY)
    growth = growth_val.nil? ? calculate_growth_rate(public_key) : growth_val

    return BigFloat.new(0) if time >= DURATION || time < 0
    INITIAL_RATE * Math.exp(growth * time)
  end

  def get_price (public_key)
    stack_size = @game.get_powerup_stack public_key, PowerupParasite.get_powerup_id
    price = stack_size > 0 ? BASE_PRICE * (PRICE_MULTIPLIER * stack_size) : BASE_PRICE
    BigFloat.new price
  end

  def is_available_for_purchase (public_key)
    ((@game.get_player_time_units public_key) >= (get_price public_key)) && (cooldown_seconds_left public_key) <= 0
  end

  def get_active_parasite_stack (public_key)
    @game.get_key_value_as_float public_key, KEY_ACTIVE_STACK
  end

  def inc_active_parasite_stack (public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, ((get_active_parasite_stack public_key) + 1).to_s
  end

  def reset_active_parasite_stack (public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, "0"
  end

  def buy_action (public_key)
    if !public_key
      return "Something went wrong."
    end

    if !(is_available_for_purchase public_key)
      return "You do not have enough units."
    end

    puts "#{public_key} purchased parasite"

    inc_active_parasite_stack public_key

    @game.add_powerup public_key, PowerupParasite.get_powerup_id
    @game.inc_time_units public_key, -(get_price public_key)

    if @game.is_timer_expired public_key, KEY_DURATION
      @game.set_timer public_key, KEY_DURATION, DURATION
    end

    @game.set_timer public_key, KEY_NEXT_TAKE_COOLDOWN, NEXT_TAKE_COOLDOWN
    @game.inc_powerup_stack public_key, PowerupParasite.get_powerup_id
  end

  def action (public_key, dt)
    current_time = (DURATION - 1) - (@game.get_timer_seconds_left public_key, KEY_DURATION)
    percent_steal = steal_rate_at(current_time, public_key)

    if !(@game.is_timer_expired public_key, KEY_DURATION) && (@game.is_timer_expired public_key, KEY_NEXT_TAKE_COOLDOWN)
      puts "Parasite action for #{public_key}"
      player_left_and_right = @game.get_player_to_left_and_right public_key

      left = player_left_and_right[0]
      right = player_left_and_right[1]

      puts "#{public_key} LEFT #{left} RIGHT #{right}"

      total = 0

      if left && left != public_key && !@game.has_powerup left, PowerupForceField.get_powerup_id
        left_units = @game.get_player_time_units left
        amount = left_units * percent_steal

        total += amount

        puts "#{public_key} TAKING #{amount} FROM LEFT #{left} (#{@game.get_player_name left}) who has #{left_units}"

        @game.inc_time_units left, -amount
        @game.inc_time_units public_key, amount
        @game.send_animation_event left, Animation::NUMBER_FLOAT, { "value" => "Parasite -#{amount.round(2)}", "color" => "#E9CFA0" }
      end

      if right && right != public_key && !@game.has_powerup right, PowerupForceField.get_powerup_id
        right_units = @game.get_player_time_units right
        amount = right_units * percent_steal

        puts "#{public_key} TAKING #{amount} FROM RIGHT #{right} (#{@game.get_player_name right}) who has #{right_units}"

        total += amount

        @game.inc_time_units right, -amount
        @game.inc_time_units public_key, amount
        @game.send_animation_event right, Animation::NUMBER_FLOAT, { "value" => "Parasite -#{amount.round(2)}", "color" => "#E9CFA0" }
      end

      @game.send_animation_event public_key, Animation::NUMBER_FLOAT, { "value" => "Parasite +#{total.round(2)}", "color" => "#E9A0CF" }
      @game.set_timer public_key, KEY_NEXT_TAKE_COOLDOWN, NEXT_TAKE_COOLDOWN
    end
  end

  def cleanup (public_key)
    if @game.is_timer_expired public_key, KEY_DURATION
      puts "Parasite expired for #{public_key}"
      reset_active_parasite_stack public_key
      @game.remove_powerup public_key, PowerupParasite.get_powerup_id
    end
  end
end
