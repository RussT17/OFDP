class CotsController < ApplicationController
  #Commitment of Traders Controller
  def show
    @cot = Cot.find(params[:id])
    @rows = @cot.cot_data_rows.order('date DESC')
    text = 'Date; '
    if @cot.legacy
		  text << "Non-Commercial Long; Non-Commercial Short; Non-Commercial Spreads; Commercial Long; Commercial Short; Total Long; Total Short; Nonreportable Positions Long; Nonreportable Positions Short\n"
		else
		  text << "Producer/Merchant/Processor/User Long; Producer/Merchant/Processor/User Short; Swap Dealers Long; Swap Dealers Short; Swap Dealers Spreading; Managed Money Long; Managed Money Short; Managed Money Spreading; Other Reportables Long; Other Reportables Short; Other Reportables Spreading\n"
		end
		@rows.each do |row|
			text << (row.date.to_s + "\s" + row.data).strip.gsub(/\s+/,'; ')
			text << "\n"
		end
		send_data text, :type => 'text/plain', :disposition => 'inline'
  end
  
  def index
    @contents = Cot.order('name').page(params[:page])
  end
end