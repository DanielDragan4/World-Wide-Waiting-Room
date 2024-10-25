require "../powerup"
require "json"
require "./unit_multiplier"
require "./compound_interest"

class PowerupOverCharge < Powerup
  STACK_KEY = "overcharge_stack"
  ACTIVE_STACK_KEY = "overcharge_active_stack"
  BASE_PRICE = 100.0
  UNIT_MULTIPLIER = 5.0
  DURATION = 120
  KEY_DURATION = "overcharge_duration"
  OVERCHARGE_OWENED_KEY = "overcharge_owned"

  PASSIVE_POWERUP_KEYS = [
    PowerupUnitMultiplier.get_powerup_id,
    PowerupCompoundInterest.get_powerup_id
  ]


  def self.get_powerup_id
    "overcharge"
  end

  def get_name
    "Over Charge"
  end

  def is_afflication_powerup(public_key)
    true
  end

  def is_stackable
    true
  end

  def get_description(public_key)
    "Increases Unit production by 5x but disables all passive powerups for 2 minutes. Prices increase with each additional purchase"
  end

  def get_price (public_key)
    stack_size = get_player_stack_size(public_key)
    price = (BASE_PRICE * (stack_size ** 4)).round(2)
  end

  def is_available_for_purchase(public_key)
    price = get_price(public_key)

    return ((@game.get_player_time_units public_key) >= price)
  end

  def max_stack_size (public_key)
    500
  end

  def get_player_stack_size(public_key)
    if public_key
      size = @game.get_key_value(public_key, STACK_KEY)
      size.to_s.empty? ? 1 : size.to_i
    else
      1
    end
  end

  def buy_action (public_key)
    if public_key
      if is_available_for_purchase(public_key)
        @game.add_powerup public_key, PowerupOverCharge.get_powerup_id

        current_stack = get_player_stack_size(public_key)
        price = get_price(public_key)

        puts "Purhcased Over Charge!"
        @game.add_powerup public_key, PowerupOverCharge.get_powerup_id
        @game.set_player_time_units public_key, ((@game.get_player_time_units public_key) - price)

        a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
        active_stack = a_s.nil? ? 0 : @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY

        durations = Array(String)
        passive_powerups = Array(Bool)

        if (!active_stack.nil?) && (active_stack > 0) 
            durations = Array(String).from_json(@game.get_key_value public_key, KEY_DURATION)
            durations << ((@game.ts + DURATION).to_s)

        else 
            durations = [(@game.ts + DURATION).to_s]

            if(active_stack == 0)
                owned_powerups = [] of String
                PASSIVE_POWERUP_KEYS.each do |p|
                    if  @game.has_powerup public_key, p
                        owned_powerups << p
                        @game.remove_powerup public_key, p
                    end
                end
    
                puts owned_powerups
              
                @game.set_key_value public_key, OVERCHARGE_OWENED_KEY, owned_powerups.to_json 
            end
        end
        unit_rate = @game.get_player_time_units_ps(public_key)
        overcharge_rate = unit_rate * UNIT_MULTIPLIER
        @game.set_player_time_units_ps(public_key, overcharge_rate)

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
  end

  def cleanup (public_key)
    if public_key
      durations = Array(String).from_json(@game.get_key_value public_key, KEY_DURATION)

      a_s = @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY
      active_stack = a_s.nil? ? 0 : @game.get_key_value_as_float public_key, ACTIVE_STACK_KEY

      if (!durations.nil?) && (!durations.empty?) && (!active_stack.nil?)
          duration = durations[0].to_i
          current_time = @game.ts
          unit_rate = @game.get_player_time_units_ps(public_key)

          if (duration < current_time)
            durations.delete_at(0)
            @game.set_key_value public_key, KEY_DURATION,  durations.to_json

            overcharge_rate = unit_rate / UNIT_MULTIPLIER
            @game.set_player_time_units_ps(public_key, overcharge_rate)

              
            new_active_stack = active_stack - 1  
            @game.set_key_value(public_key, ACTIVE_STACK_KEY, new_active_stack.to_s)

            if(durations.size == 0)
                saved_powerups = @game.get_key_value public_key, OVERCHARGE_OWENED_KEY 
                @game.remove_powerup public_key, PowerupOverCharge.get_powerup_id

                if (!saved_powerups.nil?) && (!saved_powerups.empty?)
                    pu_array = Array(String).from_json saved_powerups
                    pu_array.each do |p|
                    @game.add_powerup public_key, p
                    end
                end
            end
            @game.set_key_value public_key, ACTIVE_STACK_KEY, (active_stack -1).to_s
        else
            nil
        end
      end
    end
  end
end
