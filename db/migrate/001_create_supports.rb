class CreateSupports < ActiveRecord::Migration
  def self.up
    create_table :supports do |t|
      t.column :id, :int
      t.column :trackid, :string
      t.column :email, :string
      t.column :cc, :string
      t.column :name, :string
      t.column :issueid, :integer 
      t.column :original_mail_headers, :text
    end
    add_index  :supports, :trackid, :unique => true
    add_index  :supports, :issueid, :unique => true
  end

  def self.down
    drop_table :supports
  end
end
