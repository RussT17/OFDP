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

ActiveRecord::Schema.define(:version => 20120718190613) do

  create_table "assets", :force => true do |t|
    t.string "symbol"
    t.string "exchange"
    t.string "name"
  end

  create_table "bad_future_data_rows", :force => true do |t|
    t.string  "exchange"
    t.string  "symbol"
    t.integer "year"
    t.string  "month"
    t.date    "date"
    t.float   "open"
    t.float   "high"
    t.float   "low"
    t.float   "settle"
    t.float   "volume"
    t.float   "interest"
  end

  create_table "cfcs", :force => true do |t|
    t.integer "asset_id"
    t.integer "depth"
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
    t.integer "cfc_id"
  end

  add_index "future_data_rows", ["date"], :name => "index_future_data_rows_on_date"

  create_table "futures", :force => true do |t|
    t.integer "asset_id"
    t.string  "month"
    t.integer "year"
  end

  create_table "invalid_contract_months", :force => true do |t|
    t.integer "asset_id"
    t.string  "month"
  end

  create_table "metal_datasets", :force => true do |t|
    t.integer "metal_id"
    t.string  "table"
    t.string  "name"
  end

  create_table "metals", :force => true do |t|
    t.string "name"
    t.string "source"
  end

  create_table "non_prec_prices", :force => true do |t|
    t.integer "metal_dataset_id"
    t.date    "date"
    t.float   "buyer"
    t.float   "seller"
    t.float   "mean"
  end

  create_table "precious_fixings", :force => true do |t|
    t.integer "metal_dataset_id"
    t.date    "date"
    t.float   "usd"
    t.float   "gbp"
    t.float   "eur"
  end

  create_table "precious_forwards", :force => true do |t|
    t.integer "metal_dataset_id"
    t.date    "date"
    t.float   "gofo1"
    t.float   "gofo2"
    t.float   "gofo3"
    t.float   "gofo6"
    t.float   "gofo12"
    t.float   "libor1"
    t.float   "libor2"
    t.float   "libor3"
    t.float   "libor6"
    t.float   "libor12"
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
