
require "../powerup"
require "json"
require "./unit_multiplier"
require "./compound_interest"

class PowerupOverCharge < Powerup
  STACK_KEY = "overcharge_stack"
  ACTIVE_STACK_KEY = "overcharge_active_stack"
  BASE_PRICE = BigFloat.new 25.0
  UNIT_MULTIPLIER = BigFloat.new 5.0
  DURATION = 60
  KEY_DURATION = "overcharge_duration"

  def self.get_powerup_id
    "overcharge"
  end

  def category
    PowerupCategory::ACTIVE
  end

  def get_name
    "Overcharge"
  end

  def player_card_powerup_icon (public_key)
    "/overcharge.png"
  end

  def is_stackable
    true
  end

  def get_popup_info (public_key) : PopupInfo
    durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)
    duration = BigFloat.new durations[0][0]

    pi = PopupInfo.new
    pi["Time Left"] = (duration - @game.ts).to_s
    pi["Units/s Boost"] = "#{(get_unit_boost(public_key))}x"
    pi["Overcharge Stack"] = (@game.get_key_value_as_float public_key, ACTIVE_STACK_KEY).to_s
    pi
  end

  def get_description(public_key)
        amount = ((get_unit_boost(public_key)) * new_multiplier(public_key)).round(2)
        "Increases unit production by #{amount}x for 1 min, but disables all passive powerups while active.
        <br>Price increases exponentially as active stack size increases. Base price increases with each purchase."
  end

  def get_price (public_key)
    active_stack = (@game.get_key_value_as_float public_key, ACTIVE_STACK_KEY)
    unit_ps = @game.get_player_time_units_ps(public_key)
    unit_ps_price_multi = (unit_ps / 100000) + 1

    stack_size = BigInt.new get_player_stack_size(public_key)
    p1 = BigFloat.new (unit_ps_price_multi * BASE_PRICE)
    p2 = BigInt.new (((active_stack + 1) /2 ) * 3)

    price = (p1 * (stack_size ** p2)).round(2)

    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage price, BigFloat.new alterations.active_price
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)
    is_active = !(@game.has_powerup public_key, PowerupRelativisticShift.get_powerup_id)

    return (((@game.get_player_time_units public_key) >= price) && is_active)
  end

  def max_stack_size (public_key)
    10000
  end

  def new_multiplier(public_key) : BigFloat
    get_synergy_boosted_multiplier(public_key, UNIT_MULTIPLIER)
  end

  def get_player_stack_size(public_key)
    @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 1)
  end

  def get_unit_boost(public_key) : BigFloat
    return BigFloat.new 1.0 if !@game.has_powerup(public_key, PowerupOverCharge.get_powerup_id)

    durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)
    boost_units = BigFloat.new 1.0

    if !durations.nil?
      durations.each do |t|
        boost_units *=  BigFloat.new(t[1])
      end
    end
    boost_units.round 2
  end

  def buy_action (public_key)
    if public_key
      if is_available_for_purchase(public_key)
        @game.add_powerup public_key, PowerupOverCharge.get_powerup_id
        @game.add_active public_key

        current_stack = get_player_stack_size(public_key)
        price = get_price(public_key)

        puts "Purhcased Over Charge!"
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) - price)

        a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
        active_stack = a_s.nil? ? 0 : a_s

        durations = Array(Array(String))

        if (!active_stack.nil?) && (active_stack > 0)
            durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)
            durations << [((@game.ts + DURATION).to_s), (new_multiplier public_key).to_s]
        else
            durations = [[((@game.ts + DURATION).to_s), (new_multiplier public_key).to_s]]
        end

        @game.set_key_value public_key, KEY_DURATION,  durations.to_json

        new_stack = current_stack + 1
        @game.set_key_value(public_key, STACK_KEY, new_stack.to_s)

        if !active_stack.nil?
            new_active_stack = active_stack + 1
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)
        else
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, "1")
        end

      else
        puts "Your Dont have Enough units Left"
      end
    else
      nil
    end
  end

  def action (public_key, dt)
    puts "OVERCHARGE ACTION #{@game.ts}"
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && !(@game.has_powerup public_key, PowerupRelativisticShift.get_powerup_id)

        unit_rate =  BigFloat.new(@game.get_player_time_units_ps(public_key))
        overcharge_rate = (unit_rate * (get_unit_boost(public_key))) -unit_rate
        BigFloat.new(overcharge_rate).round(2)

        @game.inc_time_units_ps public_key, overcharge_rate
    end
  end

  def cleanup (public_key)
    if public_key
      a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
      active_stack = a_s.nil? ? 0 : a_s

        durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)

      if (!durations.nil?) && (!durations.empty?) && (!active_stack.nil?)
          duration = force_big_int durations[0][0]
          current_time = @game.ts

          if (duration < current_time)
            durations.delete_at(0)
            @game.set_key_value public_key, KEY_DURATION,  durations.to_json

            new_active_stack = active_stack - 1
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)

            if(durations.size == 0)
                @game.remove_powerup public_key, PowerupOverCharge.get_powerup_id
            end
            @game.set_key_value public_key, ACTIVE_STACK_KEY, (active_stack -1).to_s
        else
            nil
        end
      end
    end
  end
end
