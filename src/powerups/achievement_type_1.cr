require "../powerup"

class AchievementTypeI < Powerup
  UNITS_MILESTONE = BigFloat.new (4 * 10e12)
  UPS_BOOST = BigFloat.new 100

  def self.get_powerup_id
    "achievement_type_1"
  end

  def get_name
    "Type I Civilization"
  end

  def get_description (public_key)
    "Reach 4 * 10<sup class=\"font-bold\">12</sup> units.<br>Gives a permanent 100 units/s boost."
  end

  def is_achievement_powerup (public_key)
    true
  end

  def action (public_key, dt)
    pu_id = AchievementTypeI.get_powerup_id
    if !(@game.has_powerup public_key, pu_id)
      tu = @game.get_player_time_units public_key
      if tu >= UNITS_MILESTONE
        @game.add_powerup public_key, pu_id
        @game.send_animation_event public_key, Animation::NUMBER_FLOAT, { "value" => "Type I Civilization Achieved", "color" => "#05FF05" }
      end
    else
      @game.inc_time_units_ps public_key, UPS_BOOST
    end
  end
end
