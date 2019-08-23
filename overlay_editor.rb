require 'sinatra'
require 'yaml'

def maximum( a, b)
  return b if a.nil?
  return a if b.nil?
  (a < b) ? b : a
end

def minimum( a, b)
  return b if a.nil?
  return a if b.nil?
  (a < b) ? a : b
end

defn_file = ARGV[0]
defn = YAML.load( IO.read( defn_file))

get '/' do
  if defn['lat'] && defn['lon']
    lat, lon = defn['lat'], defn['lon']
  else
    lat0 = lon0 = lat1 = lon1 = nil

    defn['places'].each do |place|
      lat0 = minimum( lat0, place['lat'])
      lon0 = minimum( lon0, place['lon'])
      lat1 = maximum( lat1, place['lat'])
      lon1 = maximum( lon1, place['lon'])
    end

    lat = 0.5 * (lat0 + lat1)
    lon = 0.5 * (lon0 + lon1)
  end

  defn['places'].each do |place|
    if place['x'].nil?
      place['x'] = place['y'] = 100
    end
  end


  erb :overlay_editor, :locals => {:tiles  => defn['tiles'],
                                   :width  => defn['width'],
                                   :height => defn['height'],
                                   :places => defn['places'],
                                   :lat    => lat,
                                   :lon    => lon,
                                   :zoom   => defn['zoom']}
end

post "/update_place/:index/:x/:y" do
  place      = defn['places'][params[:index].to_i]
  place['x'] = params[:x].to_i
  place['y'] = params[:y].to_i

  File.open( defn_file, 'w') do |io|
    io.puts defn.to_yaml
  end
end

post "/update_map/:lat/:lon/:zoom" do
  defn['lat'] = params[:lat].to_f
  defn['lon'] = params[:lon].to_f
  defn['zoom'] = params[:zoom].to_i

  File.open( defn_file, 'w') do |io|
    io.puts defn.to_yaml
  end
end