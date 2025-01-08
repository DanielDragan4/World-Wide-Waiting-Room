require "../powerup"
require "./force_field.cr"

class AfflictPowerupBlackHole < Powerup
  STEAL_AMOUNTS = [0.05, 0.125, 0.25, 0.5]
  KEY_DISTANCE = "black_hole_dist"
  KEY_BIGGEST_DEC = "black_hole_dec"

  def get_name
    "Black Hole"
  end

  def self.get_powerup_id
    "afflict_black_hole"
  end

  def is_afflication_powerup (public_key)
    true
  end

#   def buy_action (public_key)
#     @game.add_powerup public_key, AfflictPowerupBlackHole.get_powerup_id
#     @game.set_timer public_key, COOLDOWN_KEY, (get_cooldown_time public_key).to_i64
#   end

  def action (public_key, dt)
    if (@game.has_powerup public_key, PowerupForceField.get_powerup_id) #|| (@game.has_powerup public_key, AfflictPowerupBlackHole.get_powerup_id)
      return
    end

    percent_dec = @game.get_key_value_as_int public_key, KEY_DISTANCE
    biggest_dec = @game.get_key_value_as_int public_key, KEY_BIGGEST_DEC

    if !(biggest_dec.nil?) || (biggest_dec == 0)
        if biggest_dec < percent_dec
            @game.set_key_value public_key, KEY_BIGGEST_DEC, percent_dec.to_s
            biggest_dec = percent_dec
        end
    else
        @game.set_key_value public_key, KEY_BIGGEST_DEC, percent_dec.to_s
    end



    player_tups = @game.get_player_time_units_ps public_key
    dec = BigFloat.new(STEAL_AMOUNTS[biggest_dec-1])
    amount_dec = player_tups * dec
    puts "#{amount_dec} FROM LEFT #{public_key} (#{@game.get_player_name public_key}) who has #{player_tups}"
    @game.send_animation_event public_key, Animation::NUMBER_FLOAT, { "value" => "black_hole -#{amount_dec.round(2)}", "color" => "#df1700" }

    @game.inc_time_units_ps public_key, -amount_dec
  end

  def cleanup (public_key)
    @game.remove_powerup public_key, AfflictPowerupBlackHole.get_powerup_id
  end
end
