class EnhanceSupports < ActiveRecord::Migration
  def self.up
    add_column :supports, :cc, :string
    add_index  :supports, :trackid, :unique => true
  end

  def self.down
    remove_column :supports, :cc
    remove_index  :supports, :trackid
  end
end
