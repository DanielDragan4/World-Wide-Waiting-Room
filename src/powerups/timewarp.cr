require "../powerup"
require "big"
require "json"

class PowerupTimeWarp < Powerup
  STACK_KEY = "timewarp_stack"
  ACTIVE_STACK_KEY = "active_stack"
  BASE_PRICE = BigFloat.new 100.0
  UNIT_MULTIPLIER = BigFloat.new 2.0
  DURATION = 600
  KEY_DURATION = "timewarp_duration"

  def category
    PowerupCategory::ACTIVE
  end

  def new_multiplier(public_key) : BigFloat
    get_synergy_boosted_multiplier(public_key, UNIT_MULTIPLIER)
  end

  def self.get_powerup_id
    "timewarp"
  end

  def get_name
    "Time Warp"
  end

  def is_stackable  
    true
  end

  def get_popup_info (public_key) : PopupInfo
    durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)

    pi = PopupInfo.new
    pi["Time Left"] = (BigFloat.new(durations[0][0]) - @game.ts).to_s
    pi["Units/s Boost"] = "#{(get_unit_boost(public_key)).round(2)}x"
    pi["Time Warp Stack"] = (@game.get_key_value_as_float public_key, ACTIVE_STACK_KEY).to_s
    pi
  end

  def get_description(public_key)

    amount = ((get_unit_boost(public_key)) * new_multiplier(public_key)).round(2)
    "Multiplies unit production by #{amount}x for the next 10 minutes. Price increases exponentially. Active Time Warps are stackable, with each additional purchase increasing the base price exponentially. Each active Time Warp amplifies this exponential rate, making growth even faster until the active Time Warp expires."
  end

  def get_price (public_key)
    stack_size = get_player_stack_size(public_key)
    unit_ps = @game.get_player_time_units_ps(public_key)
    unit_ps_price_multi = (unit_ps / 100000) + 1
    active_stack = (@game.get_key_value_as_int public_key, ACTIVE_STACK_KEY)

    stack_size = BigInt.new get_player_stack_size(public_key)
    p1 = BigFloat.new (unit_ps_price_multi * BASE_PRICE)
    p2 = BigInt.new ((active_stack + 1)/2)

    price = (p1 * (stack_size ** (p2 * 4))).round(2)

    alterations = @game.get_cached_alterations
    @game.increase_number_by_percentage price, BigFloat.new alterations.active_price
  end

  def player_card_powerup_icon (public_key)
    "/timewarp.png"
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)
    is_active = !(@game.has_powerup public_key, PowerupRelativisticShift.get_powerup_id)

    return (((@game.get_player_time_units public_key) >= price) && is_active)
  end

  def max_stack_size (public_key)
    10000
  end

  def get_player_stack_size(public_key)
    @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 1)
  end

  # def get_player_active_stack_size(public_key)
  #   @game.get_key_value_as_int(public_key, STACK_KEY, BigInt.new 0)
  # end

  def get_unit_boost(public_key)
    return 1.0 if !@game.has_powerup(public_key, PowerupTimeWarp.get_powerup_id)

    durations = Array(Array(String)).from_json(@game.get_key_value public_key, KEY_DURATION)
    boost_units = BigFloat.new 1.0
    durations.each do |t|
      boost_units *= BigFloat.new t[1]
    end
    boost_units.round(2)
  end

  def buy_action (public_key)

    if public_key
      if is_available_for_purchase(public_key)

        c_s = get_player_stack_size(public_key)
        current_stack = c_s.nil? ? 0 : c_s
        price = get_price(public_key)

        puts "Purhcased Time Warp!"
        @game.add_powerup public_key, PowerupTimeWarp.get_powerup_id
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) - price)
        @game.add_active public_key

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
    nil
  end

  def action (public_key, dt)
    if public_key && !(@game.has_powerup public_key, PowerupHarvest.get_powerup_id) && !(@game.has_powerup public_key, PowerupRelativisticShift.get_powerup_id)
        unit_rate =  BigFloat.new(@game.get_player_time_units_ps(public_key))
        timewarp_rate = (unit_rate * (get_unit_boost(public_key))) - unit_rate

        @game.inc_time_units_ps public_key, timewarp_rate.round(2)
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
            if(active_stack <= 1)
              @game.remove_powerup public_key, PowerupTimeWarp.get_powerup_id
            end

              durations.delete_at(0)
              @game.set_key_value public_key, KEY_DURATION,  durations.to_json

              new_active_stack = active_stack - 1
              @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)
          else
              nil
          end
      end
    end
  end
end
