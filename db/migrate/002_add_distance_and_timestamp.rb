class AddDistanceAndTimestamp < ActiveRecord::Migration
  def self.up
    add_column :users, :distance, :decimal, :precision => 10, :scale => 2
    add_column :users, :timestamp, :datetime
  end

  def self.down
    remove_column :users, :distance
    remove_column :users, :timestamp
  end
end
