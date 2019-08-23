#
# Generate HTML source pages for displaying
# information on maps
#
# Command line:
#   Base map data file
#   Header file
#   Footer file
#   Width for SVG frame
#   Base output filename (no extension)
#
# -------------------------------------------------------
#
require 'json'
require 'yaml'

class RenderMaps
  def initialize( header, footer, width, output)
    @header = IO.read( header)
    @footer = IO.read( footer)
    @width = width
    @output = output
    @plotted = {}
    @pages = Hash.new {|h,k| h[k] = @output + "_#{h.size+1}.html"}
  end
  
  def convert_plot_to_geojson( plot, output)
    File.open( output, 'w') do |io|
      io.puts <<"HEADER"
{
"type": "FeatureCollection",
"name": "ne_10m_admin_0_map_subunits",
"crs": { "type": "name", "properties": { "name": "urn:ogc:def:crs:OGC:1.3:CRS84" } },
"features": [
HEADER

      load_csv_file( plot).each do |row|
        io.puts <<"RECORD"
{"type":"Feature",
"geometry": {"type": "Point", "coordinates": [#{row['lon']}, #{row['lat']}]},
"properties": {"name": "#{row['name']}", "url": "#{row['url']}", "lat" : #{row['lat']}, "lon" : #{row['lon']}}
},
RECORD
        @plotted[row['name']] = false
      end
      
      io.puts <<"FOOTER"
]
}
FOOTER
    end
  end
  
  def finish( plots, io)
    return if io.nil?
    plots['features'].each do |plot|
       render_plot( plot, bounds, height, leaf, io)
    end
    io.puts " </svg>"
    io.print @footer
    io.close
  end
  
  def generate( basemaps, plot)
    convert_plot_to_geojson( plot, '/tmp/plot.json')
    keys = Hash.new {|h,k| h[k] = (h.size+1)}
    plots = {'features':[]}
    leaf = false
    
    IO.readlines( basemaps).each do |line|
      line = line.chomp
      if m = /^root (.*)$/.match( line)
        @pages[m[1]] = @output + '.html'
      elsif m1 = /^key (.*)$/.match( line)
        finish( plots, io)
        io = File.new( @pages[m[1]])
        leaf = ! (/\(/ =~ m1[1])
      elsif m2 = /^bounds (.*)$/.match( line)
        bounds = m2.split(' ').collect {|c| c.to_f}
        height = (@width * (bounds[3] - bounds[1]) / (bounds[2] - bounds[0])).to_i
        io.puts " <svg xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"#{@width}\" height=\"#{height}\">"
      elsif m3 = /^projection (.*)$/.match( line)
        if ! system( "ogr2ogr -f GeoJSON -t_srs #{base['projection']} /tmp/plot1.json /tmp/plot.json")
          raise "Error running ogr2ogr"
        end
        plots = JSON.parse( IO.read( '/tmp/plot1.json'))
      elsif m4 = /^coordinates (.*)$/.match( line)
        coords = m4.split(' ').collect {|pair| pair.split(',').collect {|c| c.to_f}}
        send( * command, coords, height, io)
      elsif m5 = /^polygon (.*)$/.match( line)
        command = [:render_polygon, m5[1]]
      elsif /^line$/ =~ line
        command = [:render_line]
      elsif m6 = /^text (.*)$/.match( line)
        command = [:render_text, m5[1]]
      elsif m7 = /^link (.*)$/.match( line)
        command = [:render_hotspot, m5[1]]
      else
        raise "Unhandled line: #{line}"
      end
    end

    finish( plots, io)
  end
	
	def render_coord( x, y, bounds, height)
		xmin, ymin, xmax, ymax = * bounds
		x = @width * (x - xmin) / (xmax - xmin)
		y = height * (ymax - y) / (ymax - ymin)
		return x.to_i, y.to_i
	end
	
	def render_coords( xys, bounds, height)
    coords = xys.collect {|c| render_coord( c[0], c[1], bounds, height)}
    
		last = nil
		coords = coords.select do |coord|
			if last.nil? || (coord[0] != last[0]) || (coord[1] != last[1])
				last = coord
				true
			else
				false
			end
		end

		coords.collect {|c| "#{c[0]},#{c[1]}"}
	end

  def render_hotspot( hotspot, bounds, height, io)
    coords = render_coords( hotspot['coordinates'], bounds, height)
    link = @output + "#{hotspot['target']}.html"
    fill = hotspot['fill']
    io.puts " <a target=\"_parent\" xlink:href=\"#{link}\"><polygon points=\"#{coords.join( ' ')}\" style=\"fill:#{fill};stroke:none;opacity:0.01\" /></a>"
  end

  def render_line( line, bounds, height, io)
    coords = render_coords( line['coordinates'], bounds, height)
    io.puts " <polyline points=\"#{coords.join( ' ')}\" style=\"fill:none;stroke:black;stroke-width:1\" />"
  end
  
	def render_plot( plot, bounds, height, leaf, io)
		x, y = render_coord( * plot['geometry']['coordinates'], bounds, height)
    return if (x < 0) || (x > @width) || (y < 0) || (y > height)
    postfix = '/>'
    prefix = ' '
    radius = 3
    
    if leaf
      name = plot['properties']['name']
      @plotted[name] = true
      postfix = "><title>#{name}</title></circle></a>"
      
      url = plot['properties']['url']
      if url.nil? or (url.strip == '')
        lat = plot['properties']['lat']
        lon = plot['properties']['lon']
        url = "https://maps.apple.com/?ll=#{lat},#{lon}&spn=0.082862,0.185541&t=m"
      end
      
      prefix = " <a target=\"_parent\" xlink:href=\"#{url}\">"
      radius = 5
    end

    io.puts prefix + "<circle cx=\"#{x}\" cy=\"#{y}\" r=\"#{radius}\" fill=\"black\" stroke=\"red\"" + postfix
	end

  def render_polygon( polygon, bounds, height, io)
    coords = render_coords( polygon['coordinates'], bounds, height)
    fill = polygon['fill']
    io.puts " <polygon points=\"#{coords.join( ' ')}\" style=\"fill:#{fill};stroke:#{fill};stroke-width:1\" />"
  end
  
	def render_text( text, bounds, height, io)
		x, y = render_coord( * text['coordinates'][0], bounds, height)
    io.puts " <text x=\"#{x}\" y=\"#{y}\" fill=\"black\" text-anchor=\"middle\">#{text['text']}</text>"
	end
	
  def report_errors
    abend = false
    @plotted.each_pair do |name,flag|
      if not flag
        puts "*** Not on leaf: #{name}"
        abend = true
      end
    end
    raise "Errors in rendering" if abend
  end
  
  def start( key)
    io = File.new( @pages[m[1]])
    io
  end
  
	def load_csv_file( path)
		lines = IO.readlines( path).collect {|l| l.chomp}
		loaded = []
		columns = load_csv_line( lines[0])
		lines[1..-1].each do |line|
			fields = load_csv_line( line)
			row = {}
			columns.each_index {|i| row[columns[i]] = fields[i]}
			loaded << row
		end
		loaded
	end
	
	def load_csv_line( line)
		fields = []
		while m = /^("[^"]*"|[^",]*),(.*)$/.match( line)
			fields << unquote(m[1]) # (/^"/ =~ m[1]) ? m[1][1...-1] : m[1]
			line = m[2]
		end
		fields << unquote(line)
		#p fields
		fields
	end
	
	def unquote( text)
		return nil if text.size < 1
		return text[1...-1] if text[0][0] == '"'
		text
	end
end

r = RenderMaps.new( ARGV[1], ARGV[2], ARGV[3].to_i, ARGV[-1])
r.generate( ARGV[0], ARGV[-2])
r.report_errors
