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

ActiveRecord::Schema.define(:version => 20120716145517) do

  create_table "assets", :force => true do |t|
    t.string "symbol"
    t.string "exchange"
    t.string "name"
  end

  create_table "future_data_rows", :force => true do |t|
    t.integer "future_id"
    t.date    "date"
    t.float   "open"
    t.float   "high"
    t.float   "low"
    t.float   "settle"
    t.integer "volume"
    t.integer "interest"
    t.integer "front_rank"
  end

  create_table "futures", :force => true do |t|
    t.integer "asset_id"
    t.string  "month"
    t.integer "year"
  end

  create_table "stock_option_data_rows", :force => true do |t|
    t.integer "stock_option_id"
    t.date    "date"
    t.float   "last_trade_price"
    t.float   "change"
    t.float   "bid"
    t.float   "ask"
    t.integer "volume"
    t.integer "open_interest"
  end

  create_table "stock_options", :force => true do |t|
    t.integer "stock_id"
    t.date    "expiry_date"
    t.boolean "is_call"
    t.float   "strike_price"
    t.string  "symbol"
  end

  create_table "stocks", :force => true do |t|
    t.string "symbol"
    t.string "name"
    t.string "sector"
    t.string "exchange"
  end

end
