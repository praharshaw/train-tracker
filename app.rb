require "sinatra"
require "sinatra/formkeeper"

get '/' do
	erb :home
end

get	'/about' do
	erb :about
end

get '/contact' do
	erb :contact
end

get '/info' do
  @info = true
	erb :info
end

helpers do
  def info_page?
    @info
  end

	def validate(pnr)
		# pnr should be a string of 10 digits
		return true if pnr =~ /^\d\d\d\d\d\d\d\d\d\d$/
    return false
	end
end