require "../powerup"
require "./force_field.cr"

class AfflictPowerupBlackHole < Powerup
  STEAL_AMOUNTS = [0.5, 0.25, 0.125, 0.05]
  KEY_DISTANCE = "black_hole_dist"

  def get_name
    "Afflict Black Hole"
  end

  def self.get_powerup_id
    "afflict_black_hole"
  end

  def is_afflication_powerup (public_key)
    true
  end
  
  def player_card_powerup_icon(public_key)
    "/afflict_black_hole.png"
  end

  def get_popup_info(public_key) : PopupInfo
    dec = dec_amount(public_key)
    pi = PopupInfo.new
    pi["UPS Deacrease"] = ("#{dec*100}%")
    pi
  end

  def dec_amount(public_key)
    players_left_and_right = @game.get_black_hole_players public_key

    left = players_left_and_right[0]
    right = players_left_and_right[1]

    (0..3).each do |i|
        if (i < left.size) && !(left.empty?)
            if (@game.has_powerup left[i], PowerupBlackHole.get_powerup_id)
                  return BigFloat.new(STEAL_AMOUNTS[i])
            end
        end
        if (i < right.size) && !(right.empty?)
            if (@game.has_powerup right[i], PowerupBlackHole.get_powerup_id)
                return BigFloat.new(STEAL_AMOUNTS[i])
            end
        end
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

    @game.inc_time_units_ps public_key, -amount_dec
  end

  def cleanup (public_key)
    if (@game.has_powerup public_key, PowerupForceField.get_powerup_id) || ((dec_amount public_key) <= 0)
      @game.remove_powerup public_key, AfflictPowerupBlackHole.get_powerup_id
    end
  end
end
