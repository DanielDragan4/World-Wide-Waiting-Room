require "../powerup"
require "json"
require "./force_field.cr"
require "./afflict_black_hole.cr"
require "math"

class PowerupBlackHole < Powerup
  BASE_PRICE = BigFloat.new 100_000
  NEXT_TAKE_COOLDOWN = 1
  DURATION = 60 * 10

  PRICE_MULTIPLIER = BigFloat.new 1.3
  KEY_DURATION = "black_hole_duration"
  KEY_NEXT_TAKE_COOLDOWN = "black_hole_next_take"
  KEY_ACTIVE_STACK = "black_hole_active"
  KEY_DISTANCE = "black_hole_dist"
  KEY_PLAYERS = "black_hole_players"
  KEY_BIGGEST_DEC = "black_hole_dec"


  def category
    PowerupCategory::SABATOGE
  end

  def self.get_powerup_id
    "black_hole"
  end

  def get_popup_info(public_key) : PopupInfo
    pi = PopupInfo.new
    pi["Timer Left"] = (@game.get_timer_seconds_left public_key, KEY_DURATION)
    pi
  end

  def get_name
    "Black Hole"
  end

  def player_card_powerup_icon(public_key)
    "/blackhole.png"
  end

  def get_description(public_key)
    "Over the course of #{(DURATION / 60).to_i} minutes, steal units from players directly ahead and behind you. For players with less than 1000x your units, steals 20% of their units. For players with 1000x or more units, steals based on 10 raised to 1/4 of the logarithmic difference in units. The price increases with each purchase. Multiple black_holes can be stacked to increase the steal amount."
  end

  def get_price(public_key)
    stack_size = @game.get_powerup_stack public_key, PowerupBlackHole.get_powerup_id
    price = stack_size > 0 ? BASE_PRICE * (PRICE_MULTIPLIER * stack_size) : BASE_PRICE
    BigFloat.new price
  end

  def is_available_for_purchase(public_key)
    (((@game.get_player_time_units public_key) >= (get_price public_key)) && (cooldown_seconds_left public_key) <= 0) && !(@game.has_powerup(public_key, PowerupBlackHole.get_powerup_id)) 
  end

  def get_active_black_hole_stack(public_key)
    @game.get_key_value_as_float public_key, KEY_ACTIVE_STACK
  end

  def inc_active_black_hole_stack(public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, ((get_active_black_hole_stack public_key) + 1).to_s
  end

  def reset_active_black_hole_stack(public_key)
    @game.set_key_value public_key, KEY_ACTIVE_STACK, "0"
  end

  def buy_action(public_key)
    if !public_key
      return "Something went wrong."
    end

    if !(is_available_for_purchase public_key)
      return "You do not have enough units."
    end

    puts "#{public_key} purchased black_hole"

    inc_active_black_hole_stack public_key

    @game.add_powerup public_key, PowerupBlackHole.get_powerup_id
    @game.inc_time_units public_key, -(get_price public_key)

    if @game.is_timer_expired public_key, KEY_DURATION
      @game.set_timer public_key, KEY_DURATION, DURATION
    end

    @game.set_timer public_key, KEY_NEXT_TAKE_COOLDOWN, NEXT_TAKE_COOLDOWN
    @game.inc_powerup_stack public_key, PowerupBlackHole.get_powerup_id
  end


  def action(public_key, dt)
    if !(@game.is_timer_expired public_key, KEY_DURATION) && (@game.is_timer_expired public_key, KEY_NEXT_TAKE_COOLDOWN)
      puts "black_hole action for #{public_key}"
      players_left_and_right = @game.get_black_hole_players public_key
      current_units = @game.get_player_time_units public_key

      @game.set_key_value public_key, KEY_PLAYERS, players_left_and_right.to_json

      left = players_left_and_right[0]
      right = players_left_and_right[1]

      puts "#{public_key} LEFT #{left} RIGHT #{right}"

      total = BigFloat.new(0)

      if left
        i = 4
        left.each do |x|
            if x && x != public_key && !@game.has_powerup x, PowerupForceField.get_powerup_id
                @game.add_powerup x, AfflictPowerupBlackHole.get_powerup_id
                @game.set_key_value x, KEY_DISTANCE, i.to_s

                i -= 1
            end
        end
      end

      if right
        i = 4
        right.each do |x|
            if x && x != public_key && !@game.has_powerup x, PowerupForceField.get_powerup_id
                @game.add_powerup x, AfflictPowerupBlackHole.get_powerup_id
                @game.set_key_value x, KEY_DISTANCE, i.to_s

                i -= 1
            end
        end
        @game.set_timer public_key, KEY_NEXT_TAKE_COOLDOWN, NEXT_TAKE_COOLDOWN
      end
    end
  end

  def cleanup(public_key)
    if @game.is_timer_expired public_key, KEY_DURATION

    players = Tuple(Array(String) | Nil, Array(String) | Nil)
        
      players = Tuple(Array(String) | Nil, Array(String) | Nil).from_json(@game.get_key_value public_key, KEY_PLAYERS)
      players.each do |left_or_right|
        if !(left_or_right.nil?)
            left_or_right.each do |player|
                @game.set_key_value player, KEY_BIGGEST_DEC, "0"
            end
        end
    end


      puts "black_hole expired for #{public_key}"
      reset_active_black_hole_stack public_key
      @game.remove_powerup public_key, PowerupBlackHole.get_powerup_id
    end
  end
end