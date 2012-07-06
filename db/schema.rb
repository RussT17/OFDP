# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120705150821) do

  create_table "futures_choices", :force => true do |t|
    t.string "choice"
    t.string "field_type"
  end

  create_table "futures_contents", :force => true do |t|
    t.string "ticker"
    t.string "exchange"
    t.string "year"
    t.string "month"
  end

  create_table "futures_data_rows", :force => true do |t|
    t.date   "dt"
    t.string "exchange"
    t.string "ticker"
    t.string "month"
    t.string "year"
    t.float  "open"
    t.float  "high"
    t.float  "low"
    t.float  "settle"
    t.float  "volume"
    t.float  "interest"
  end

  add_index "futures_data_rows", ["exchange"], :name => "index_futures_data_rows_on_exchange"
  add_index "futures_data_rows", ["month"], :name => "index_futures_data_rows_on_month"
  add_index "futures_data_rows", ["ticker"], :name => "index_futures_data_rows_on_ticker"
  add_index "futures_data_rows", ["year"], :name => "index_futures_data_rows_on_year"

  create_table "ticker_symbols", :force => true do |t|
    t.string "exchange"
    t.string "symbol"
    t.string "name"
  end

end
