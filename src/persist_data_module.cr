require "./modules"

class PersistDataModule
  def initialize
    start_persist_data_fiber
  end

  def start_persist_data_fiber
    puts "Persist Data Fiber Started"
    spawn do
      loop do
        sleep 15
      end
    end
  end
end
