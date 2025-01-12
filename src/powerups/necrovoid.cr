require "../powerup.cr"

class PowerupNecrovoid < Powerup
  BASE_PRICE = BigFloat.new 2.5
  BASE_AMOUNT = BigFloat.new 1.0
  KEY = "unit_multiplier_stack"

  def get_name
    "Necrovoid"
  end

  def get_description
    <<-D
    <strong>Duration:</strong>...<br>
    <strong>-3% Unit/s (...)</strong><br>
    <br>
    Your character remains in-game when you go offline.
    D
  end

  def category
    PowerupCategory::PASSIVE
  end

  def is_stackable
    false
  end

  def get_price (public_key : String) : BigFloat
    BASE_PRICE
  end

  def buy_action(public_key)
    nil
  end

  def is_available_for_purchase(public_key)
    false
  end

  def action(public_key : String, dt)

  end

  def cleanup(public_key : String)
  end
end
