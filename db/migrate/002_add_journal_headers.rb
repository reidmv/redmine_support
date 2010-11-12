class AddJournalHeaders < ActiveRecord::Migration
  def self.up
    add_column :journals, :mail_header, :text
  end

  def self.down 
    remove_column :journals, :mail_header
  end
end
