require 'sinatra'
require 'yaml'

defn_file = ARGV[0]
defn = YAML.load( IO.read( defn_file))

offset = 0
defn['places'].each do |place|
  next if place['x']
  offset += 20
  place['x'] = offset
  place['y'] = offset
end

get '/' do
  erb :overlay_editor, :locals => {:url    => defn['url'],
                                   :width  => defn['width'],
                                   :height => defn['height'],
                                   :places => defn['places']}
end

post "/update/:id/:x/:y" do
  id, x, y = params[:id], params[:x], params[:y]
  defn['places'].each do |place|
    if place['id'] == id
      place['x'] = x.to_i
      place['y'] = y.to_i
    end
  end

  File.open( defn_file, 'w') do |io|
    io.puts defn.to_yaml
  end
end

post "/update_url" do
  defn['url'] = params[:url]

  File.open( defn_file, 'w') do |io|
    io.puts defn.to_yaml
  end
end