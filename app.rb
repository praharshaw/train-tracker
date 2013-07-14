require "sinatra"
require "net/http"
require "json"
require "curb"

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
  @pnr = params[:pnr]

  train_response = Net::HTTP.get_response(URI.parse("http://www.railpnrapi.com/#{@pnr}")).body

  if train_response =~ /Invalid PNR/
    erb :invalid_pnr
  else
    train_json = JSON.load(train_response)

    @train_num = train_json["tnum"]
    @train_date = train_json["tdate"]
    @train_date_reversed = @train_date.split('-').reverse.join('-')

    uri = URI.parse("http://coa-search-193678880.ap-southeast-1.elb.amazonaws.com/search.json?q=#{@train_num}")
    response = Net::HTTP.get_response(uri)

    hash = JSON.load(response.body)[0]
    stations = hash["routes"][0]["stations"]
    abbrev_stations = stations.scan(/\(.*?\)/).map { |e| e.gsub(/\(/, '').gsub(/\)/, '') }
    full_stations = stations.split(',').map { |e| e.split[1..-1].join(' ') }

    @stations_hash = Hash[abbrev_stations.zip(full_stations)]

    @next_stn = call_curl(abbrev_stations.join("%2C"))

    @prev_stn=''
    # @next_stn=''
    @final_destn=''

    @weather_forecast, @distance_to_destn = weather_distance_api

    erb :info
  end
end

helpers do
  def call_curl(stns)
    text_dump = `curl 'http://trainenquiry.com/RailYatri.ashx' -H 'Cookie: ASP.NET_SessionId=av2jvi45kkxgf1zemhvoe3fu; __gads=ID=da9366776debb721:T=1373759777:S=ALNI_MbTBC-RdvvVfSAJhZ5PqTylQHUoSA; OX_plg=swf|qt|wmp|shk|pm; __utma=177604064.1792347361.1373759770.1373759770.1373759770.1; __utmb=177604064.5.10.1373759770; __utmc=177604064; __utmz=177604064.1373759770.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)' -H 'Origin: http://trainenquiry.com' -H 'Accept-Encoding: gzip,deflate,sdch' -H 'Host: trainenquiry.com' -H 'Accept-Language: en-US,en;q=0.8' -H 'User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: */*' -H 'Referer: http://trainenquiry.com/TrainStatus.aspx' -H 'X-Requested-With: XMLHttpRequest' -H 'Connection: keep-alive' --data 't=15160&s=2013-07-13&codes=DURG%2CBPHB%2CR%2CTLD%2CBYT%2CBYL%2CBSP%2CUSL%2CKGB%2CBIG%2CPND%2CAPR%2CAAL%2CBUH%2CSDL%2CBRS%2CUMR%2CCHD%2CKTE%2CMYR%2CUHR%2CSTA%2CJTW%2CMJG%2CMKP%2CDBR%2CSRJ%2CNYN%2CALD%2CPLP%2CJNH%2CBOY%2CBSB%2CBCY%2CARJ%2CGCT%2CYFP%2CCBN%2CBUI%2CSTW%2CSIP%2CCPR&RequestType=Location' --compressed`

    json = JSON.load text_dump
    return json[json["keys"][0]]["station_updates"].reject { |k,v| v["status"] == "departed" }.keys.first
  end

  def weather_distance_api

    next_stn_long = @stations_hash[@next_stn]
    final_destn_long = @stations_hash[@final_destn]

    distance_hash = JSON.load(`curl 'http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20geo.distance%20where%20place1%3D%22#{next_stn_long}%22%20and%20place2%3D%22#{final_destn_long}%22&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys'`)

    next_woeid = distance_hash["query"]["results"]["distance"]["place"][0]["locality1"]["woeid"]
    dest_woeid = distance_hash["query"]["results"]["distance"]["place"][1]["locality1"]["woeid"]

    distance = distance_hash["query"]["results"]["distance"]["kilometers"]

    weather_hash = JSON.load(`curl 'http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20weather.forecast%20where%20woeid%3D#{next_woeid}&format=json&diagnostics=true'`)

    forecast = weather_hash["query"]["results"]["channel"]["item"]["forecast"][0]["text"]

    return [forecast, distance]
  end
end