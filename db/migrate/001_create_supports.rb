class CreateSupports < ActiveRecord::Migration
  def self.up
    create_table :supports do |t|
      t.column :id, :int
      t.column :trackid, :string
      t.column :email, :string
      t.column :name, :string
      t.column :issueid, :integer
    end
  end

  def self.down
    drop_table :supports
  end
end
