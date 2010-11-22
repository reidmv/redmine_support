class CreateMessageIds < ActiveRecord::Migration
  def self.up
    create_table :message_ids do |t|
      t.column :id, :int
      t.column :issue_id, :int
      t.column :message_id, :string
    end
    add_index  :message_ids, :message_id, :unique => true
    add_index  :message_ids, :issue_id, :unique => false
  end

  def self.down
    drop_table :message_ids
  end
end
