require "../powerup"

class AchievementTypeII < Powerup
  UNITS_MILESTONE = BigFloat.new (4 * 10e26)
  UPS_BOOST = BigFloat.new 1000

  def self.get_powerup_id
    "achievement_type_2"
  end

  def get_name
    "Type II Civilization"
  end

  def get_description (public_key)
    "Reach 4 * 10<sup class=\"font-bold\">26</sup> units.<br>Gives a permanent 1,000 units/s boost."
  end

  def is_achievement_powerup (public_key)
    true
  end

  def action (public_key, dt)
    pu_id = AchievementTypeII.get_powerup_id
    if !(@game.has_powerup public_key, pu_id)
      tu = @game.get_player_time_units public_key
      if tu >= UNITS_MILESTONE
        @game.add_powerup public_key, pu_id
        @game.send_animation_event public_key, Animation::NUMBER_FLOAT, { "value" => "Type II Civilization Achieved", "color" => "#05FF05" }
      end
    else
      @game.inc_time_units_ps public_key, UPS_BOOST
    end
  end
end
