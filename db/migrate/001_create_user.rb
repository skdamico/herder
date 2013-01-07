class CreateUser < ActiveRecord::Migration
  def self.up
    create_table "users" do |t|
      t.string   :device_token, :null => false
      t.string   :username, :null => false
      t.decimal  :latitude, :precision => 10, :scale => 6
      t.decimal  :longitude, :precision => 10, :scale => 6
      t.boolean  :has_arrived, :default => false
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def self.down
    raise IrreversibleMigration
  end
end
