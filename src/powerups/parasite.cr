require "../powerup"
require "json"
require "./force_field.cr"

class PowerupParasite < Powerup
  BASE_PRICE = 10_000
  NEXT_TAKE_COOLDOWN = 1
  DURATION = 60 * 10

  PERCENTAGE_STEAL_PER_SECOND = 0.02 / 60.0
  PRICE_MULTIPLIER = 10

  KEY_DURATION = "parasite_duration"
  KEY_NEXT_TAKE_COOLDOWN = "parasite_next_take"
  KEY_ACTIVE_STACK = "parasite_active_stack"

  def new_percentage_steal(public_key)
    get_synergy_boosted_multiplier public_key, (PERCENTAGE_STEAL_PER_SECOND * get_active_parasite_stack public_key)
  end

  def self.get_powerup_id
    "parasite"
  end

  def get_popup_info (public_key) : PopupInfo
    pi = PopupInfo.new
    pi["Timer Left"] = (@game.get_timer_seconds_left public_key, KEY_DURATION)
    pi["Parasite Stack"] = (get_active_parasite_stack public_key).to_i
    pi
  end

  def get_name
    "Parasite"
  end

  def player_card_powerup_icon (public_key)
    "/parasite.png"
  end

  def get_description (public_key)
    "Over the course of #{(DURATION / 60).to_i} minutes, steal a fraction of the units from the player directly ahead of you and directly behind for the next 10 minutes. The price is increased multiplicatively with each purchase. The number of active parasites can be stacked increasing the steal amount. Stacking parasites does not reset the 10 minute timer."
  end

  def get_price (public_key)
    stack_size = @game.get_powerup_stack public_key, PowerupParasite.get_powerup_id
    stack_size > 0 ? BASE_PRICE * (PRICE_MULTIPLIER * stack_size) : BASE_PRICE
  end

  def is_available_for_purchase (public_key)
    ((@game.get_player_time_units public_key) >= (get_price public_key)) && (cooldown_seconds_left public_key) <= 0
  end

  def get_active_parasite_stack (public_key)
    @game.get_key_value_as_float public_key, KEY_ACTIVE_STACK
  end

  def inc_active_parasite_stack (public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, (get_active_parasite_stack public_key) + 1
  end

  def reset_active_parasite_stack (public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, 0
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
    percent_steal = new_percentage_steal public_key

    if !(@game.is_timer_expired public_key, KEY_DURATION) && (@game.is_timer_expired public_key, KEY_NEXT_TAKE_COOLDOWN)
      puts "Parasite action for #{public_key}"
      player_left_and_right = @game.get_player_to_left_and_right public_key

      left = player_left_and_right[0]
      right = player_left_and_right[1]

      puts "#{public_key} LEFT #{left} RIGHT #{right}"

      if left && left != public_key && !@game.has_powerup left, PowerupForceField.get_powerup_id
        left_units = @game.get_player_time_units left
        amount = left_units * percent_steal

        puts "#{public_key} TAKING #{amount} FROM LEFT #{left} who has #{left_units}"

        @game.inc_time_units left, -amount
        @game.inc_time_units public_key, amount
        @game.send_animation_event left, Animation::NUMBER_FLOAT, { "value" => "Parasite -#{amount.round(2)}", "color" => "#E9CFA0" }
      end

      if right && right != public_key && !@game.has_powerup right, PowerupForceField.get_powerup_id
        right_units = @game.get_player_time_units right
        amount = right_units * percent_steal

        puts "#{public_key} TAKING #{amount} FROM RIGHT #{right} who has #{right_units}"

        @game.inc_time_units right, -amount
        @game.inc_time_units public_key, amount
        @game.send_animation_event right, Animation::NUMBER_FLOAT, { "value" => "Parasite -#{amount.round(2)}", "color" => "#E9CFA0" }
      end

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
