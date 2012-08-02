require 'date'

File.open(Dir[Rails.root.join "db/futures_file.csv"][0], 'r') do |f|
  f.each_with_index do |row,i|
    cells = row.split(';')
    asset = Asset.where(:exchange => cells[1], :symbol => cells[2]).first_or_create
    future = asset.futures.where(:year => cells[4].to_i, :month => cells[3]).first_or_create
    future.future_data_rows.where(:date => cells[0]).first_or_create.update_attributes(:open=>cells[5],:high=>cells[6],:low=>cells[7],:settle=>cells[8],:volume=>cells[9],:interest=>cells[10])
    puts i
  end
end