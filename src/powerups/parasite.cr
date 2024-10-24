require "../powerup"

class PowerupParasite < Powerup
  BASE_PRICE = 10_000
  COOLDOWN = 60 * 60 * 12
  ACTIVE_COOLDOWN = 60
  DURATION = 60 * 10

  PERCENTAGE_STEAL = 2

  KEY_COOLDOWN = "parasite_cooldown"
  KEY_DURATION = "parasite_duration"
  KEY_ACTIVE_COOLDOWN = "parasite_next_take"

  def new_percentage_steal(public_key)
    get_synergy_boosted_multiplier(public_key, (PERCENTAGE_STEAL / 100)) * 100
  end
  
  def self.get_powerup_id
    "parasite"
  end

  def get_name
    "Parasite"
  end

  def get_description (public_key)
    new_percentage_steal = new_percentage_steal(public_key)
    "Once every #{ACTIVE_COOLDOWN / 60} minutes for #{DURATION / 60} minutes steal #{new_percentage_steal.round(2)}% of the units from the player directly ahead of you and directly behind you.
This action can be used once every #{COOLDOWN / 60 / 60} hours."
  end

  def get_price (public_key)
    BASE_PRICE
  end

  def is_available_for_purchase (public_key)
    ((@game.get_player_time_units public_key) >= BASE_PRICE) && (cooldown_seconds_left public_key) <= 0
  end

  def cooldown_seconds_left (public_key)
    cd = @game.get_key_value_as_float public_key, KEY_COOLDOWN
    cd ||= 0
    cd - @game.ts
  end

  def buy_action (public_key)
    if !public_key
      return "Something went wrong."
    end

    if !(is_available_for_purchase public_key)
      return "You do not have enough units."
    end

    puts "#{public_key} purchased parasite"

    @game.add_powerup public_key, PowerupParasite.get_powerup_id
    @game.inc_time_units public_key, -BASE_PRICE

    @game.set_key_value public_key, KEY_COOLDOWN,  (@game.ts + COOLDOWN).to_s
    @game.set_key_value public_key, KEY_DURATION,  (@game.ts + DURATION).to_s
    @game.set_key_value public_key, KEY_ACTIVE_COOLDOWN, (@game.ts + ACTIVE_COOLDOWN).to_s

    nil
  end

  def action (public_key, dt)
    duration = @game.get_key_value_as_float public_key, KEY_DURATION
    active_cooldown = @game.get_key_value_as_float public_key, KEY_ACTIVE_COOLDOWN
    now = @game.ts
    percent_steal = new_percentage_steal(public_key) / 100.0

    if duration && active_cooldown && duration > now && active_cooldown < now
      puts "Parasite action for #{public_key}"
      player_left_and_right = @game.get_player_to_left_and_right public_key

      left = player_left_and_right[0]
      right = player_left_and_right[1]

      puts "#{public_key} LEFT #{left} RIGHT #{right}"

      if left
        left_units = @game.get_player_time_units left
        amount = left_units * percent_steal

        puts "#{public_key} TAKING #{amount} FROM LEFT #{left} who has #{left_units}"

        @game.inc_time_units left, -amount
        @game.inc_time_units public_key, amount
      end

      if right
        right_units = @game.get_player_time_units right
        amount = right_units * percent_steal

        puts "#{public_key} TAKING #{amount} FROM RIGHT #{right} who has #{right_units}"

        @game.inc_time_units right, -amount
        @game.inc_time_units public_key, amount
      end

      @game.set_key_value public_key, KEY_ACTIVE_COOLDOWN, (@game.ts + ACTIVE_COOLDOWN).to_s
    end
  end

  def cleanup (public_key)
    duration = @game.get_key_value_as_float public_key, KEY_COOLDOWN

    if duration && @game.ts > duration
      @game.remove_powerup public_key, PowerupParasite.get_powerup_id
    end
  end
end
