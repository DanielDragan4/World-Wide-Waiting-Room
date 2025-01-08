require "../powerup"
require "json"
require "./force_field.cr"
require "math"

class PowerupParasite < Powerup
  BASE_PRICE = BigFloat.new 10_000
  NEXT_TAKE_COOLDOWN = 1
  DURATION = 60 * 10

  BASE_STEAL_RATE = BigFloat.new 0.2
  PRICE_MULTIPLIER = BigFloat.new 1.3

  KEY_DURATION = "parasite_duration"
  KEY_NEXT_TAKE_COOLDOWN = "parasite_next_take"
  KEY_ACTIVE_STACK = "parasite_active_stack"

  def calculate_steal_amount(target_units : BigFloat, current_units : BigFloat) : BigFloat
    log_diff = Math.log10(target_units) - Math.log10(current_units)
    if log_diff > 5
      steal_amount = target_units * (log_diff / 200000)
      return BigFloat.new (steal_amount / DURATION)
    end
    if log_diff > 4
      steal_amount = target_units * (log_diff / 14000)
      return BigFloat.new (steal_amount / DURATION)
    end
    if log_diff > 3
      steal_amount = target_units * (log_diff / 1100)
      return BigFloat.new (steal_amount / DURATION)
    end
    if log_diff >= 2
      steal_amount = target_units * (log_diff / 100)
      return BigFloat.new (steal_amount / DURATION)
    end

    return BigFloat.new ((target_units * BASE_STEAL_RATE) / DURATION)
  end

  def category
    PowerupCategory::SABATOGE
  end

  def self.get_powerup_id
    "parasite"
  end

  def get_popup_info(public_key) : PopupInfo
    pi = PopupInfo.new
    pi["Timer Left"] = (@game.get_timer_seconds_left public_key, KEY_DURATION)
    pi["Parasite Stack"] = (get_active_parasite_stack public_key).to_s
    pi
  end

  def get_name
    "Parasite"
  end

  def player_card_powerup_icon(public_key)
    "/parasite.png"
  end

  def get_description(public_key)
    "Over the course of #{(DURATION / 60).to_i} minutes, steal units from players directly ahead and behind you. For players with less than 100x your units, steals 20% of their units. For players with 100x or more units, steals a smaller percentage decreasing as the difference in units is higher. The price increases with each purchase."
  end

  def get_price(public_key)
    stack_size = @game.get_powerup_stack public_key, PowerupParasite.get_powerup_id
    price = stack_size > 0 ? BASE_PRICE * (PRICE_MULTIPLIER * stack_size) : BASE_PRICE
    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage price, BigFloat.new alterations.sabatoge_price
  end

  def is_available_for_purchase(public_key)
    (((@game.get_player_time_units public_key) >= (get_price public_key)) && (cooldown_seconds_left public_key) <= 0) && !(@game.has_powerup(public_key, PowerupParasite.get_powerup_id)) 
  end

  def get_active_parasite_stack(public_key)
    @game.get_key_value_as_float public_key, KEY_ACTIVE_STACK
  end

  def inc_active_parasite_stack(public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, ((get_active_parasite_stack public_key) + 1).to_s
  end

  def reset_active_parasite_stack(public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, "0"
  end

  def buy_action(public_key)
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

  def action(public_key, dt)
    if !(@game.is_timer_expired public_key, KEY_DURATION) && (@game.is_timer_expired public_key, KEY_NEXT_TAKE_COOLDOWN)
      puts "Parasite action for #{public_key}"
      player_left_and_right = @game.get_player_to_left_and_right public_key
      current_units = @game.get_player_time_units public_key

      left = player_left_and_right[0]
      right = player_left_and_right[1]

      puts "#{public_key} LEFT #{left} RIGHT #{right}"

      total = BigFloat.new(0)

      if left && left != public_key && !@game.has_powerup left, PowerupForceField.get_powerup_id
        left_units = @game.get_player_time_units left
        amount = calculate_steal_amount(left_units, current_units) * get_active_parasite_stack(public_key)

        total += amount

        puts "#{public_key} TAKING #{amount} FROM LEFT #{left} (#{@game.get_player_name left}) who has #{left_units}"

        @game.inc_time_units left, -amount
        @game.inc_time_units public_key, amount
        @game.send_animation_event left, Animation::NUMBER_FLOAT, { "value" => "Parasite -#{amount.round(2)}", "color" => "#E9CFA0" }
      end

      if right && right != public_key && !@game.has_powerup right, PowerupForceField.get_powerup_id
        right_units = @game.get_player_time_units right
        amount = calculate_steal_amount(right_units, current_units) * get_active_parasite_stack(public_key)

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

  def cleanup(public_key)
    if @game.is_timer_expired public_key, KEY_DURATION
      puts "Parasite expired for #{public_key}"
      reset_active_parasite_stack public_key
      @game.remove_powerup public_key, PowerupParasite.get_powerup_id
    end
  end
end
