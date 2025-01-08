require "../powerup"
require "./force_field.cr"

class AfflictPowerupBlackHole < Powerup
  STEAL_AMOUNTS = [0.5, 0.25, 0.125, 0.05]
  KEY_DISTANCE = "black_hole_dist"
  

  def get_name
    "Black Hole"
  end

  def self.get_powerup_id
    "afflict_black_hole"
  end

  def is_afflication_powerup (public_key)
    true
  end

  def dec_amount(public_key)
    players_left_and_right = @game.get_black_hole_players public_key

    left = players_left_and_right[0]
    right = players_left_and_right[1]
    black_hole_found = false

    i = 0
    while !black_hole_found
        if (i < left.size) && !(left.empty?)
            puts "#{public_key} searching for blackhole #{left[i]} \n"
            if (@game.has_powerup left[i], PowerupBlackHole.get_powerup_id)
                black_hole_found = true
                puts "#{left[i]} owns blackhole"
                return BigFloat.new(STEAL_AMOUNTS[i])
            end
        end
        if (i < right.size) && !(right.empty?)
            if (@game.has_powerup right[i], PowerupBlackHole.get_powerup_id)
                black_hole_found = true
                return BigFloat.new(STEAL_AMOUNTS[i])
            end
        end
         i += 1
    end
    return BigFloat.new(0.0)
  end



  def action (public_key, dt)
    if (@game.has_powerup public_key, PowerupForceField.get_powerup_id)
      return
    end

    player_tups = @game.get_player_time_units_ps public_key
    dec = dec_amount(public_key)
    amount_dec = player_tups * dec

    # puts "#{amount_dec} FROM LEFT #{public_key} (#{@game.get_player_name public_key}) who has #{player_tups}"

    @game.send_animation_event public_key, Animation::NUMBER_FLOAT, { "value" => "black_hole -#{amount_dec.round(2)}", "color" => "#df1700" }

    @game.inc_time_units_ps public_key, -amount_dec
  end

  def cleanup (public_key)
    @game.remove_powerup public_key, AfflictPowerupBlackHole.get_powerup_id
  end
end