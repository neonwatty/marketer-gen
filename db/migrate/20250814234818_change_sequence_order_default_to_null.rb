class ChangeSequenceOrderDefaultToNull < ActiveRecord::Migration[8.0]
  def change
    change_column_default :journey_steps, :sequence_order, from: 0, to: nil
  end
end
