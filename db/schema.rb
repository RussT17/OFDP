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

ActiveRecord::Schema.define(:version => 20120628172140) do

  create_table "futures_data_rows", :force => true do |t|
    t.date    "dt"
    t.string  "exchange"
    t.string  "ticker"
    t.string  "month"
    t.integer "year"
    t.float   "open"
    t.float   "high"
    t.float   "low"
    t.float   "settle"
    t.float   "volume"
    t.float   "interest"
  end

end
