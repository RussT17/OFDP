class AddErrorLog < ActiveRecord::Migration
  def change
    create_table :rake_error_messages do |t|
      t.text :message
      t.text :backtrace
      t.timestamps
    end
  end
end