#
# Generate intermediate file from map base data
#
# Command line:
#   Control file in YAML format
#   Output intermediate file
#
# -------------------------------------------------------
#
require 'json'
require 'yaml'
require 'rgeo/geo_json'

class Generator
	def initialize( control_file, output_file)
		@control = YAML.load( IO.read( control_file))
    @cache = {}
		@pastels = make_pastels
		@pastel_index = 0
		assign_keys( @control)
    @fills = Hash.new {|h,k| h[k] = pastel_fill}
    @errors = 0
    @keys = {}

    @output_file_bak = nil
    if File.exist?( output_file)
      @output_file_bak = output_file + '.bak'
      raise "Error backing up" if not system( "cp #{output_file} #{@output_file_bak}")
    end
	end
	
  def analyse_points( polygons)
    points = {}
    
    polygons.each_index do |i|
      polygons[i].each do |coord|
        key = "#{coord[0]},#{coord[1]}"
        value = points[key]
        
        if value.nil?
          points[key] = i
        elsif value == :multiple
        elsif value != i
          points[key] = :multiple
        end
      end
    end
    
    points
  end
  
	def assign_keys( defn)
    includes = ''
    if defn['includes']
      includes = " includes=#{defn['includes'].join('|')}"
    end
    keys = ["projection=#{defn['projection']} background=#{defn['background']} margin=#{defn['margin']}#{includes}"]
    
		if defn['children']
      defn['children'].each do |child|
        assign_keys( child)
        keys << '(' + child['key'] + ')'
      end
		end
    
		defn['key'] = "#{keys.join(',')}"
	end
	
	def convert( source, projection)
    if @cache[source].nil?
      @cache[source] = records = []
      if /\.json$/ =~ source
        RGeo::GeoJSON.decode( IO.read( source)).each do |feature|
          feature_data( feature) do |name, geom|
            records << {geometry:geom, name:name}
          end
        end
      else
        factory = RGeo::Geographic.spherical_factory(srid:4326,proj4:get_proj4(4326))
        RGeo::Shapefile::Reader.open('myfile.shp', :factory => factory) do |file|
          file.each do |record|
            geom = record.geometry
            name = record['Name']
            records << {geometry:geom, name:name}
          end
        end
      end
    end
    
    key = "#{source}\t#{projection}"
    if @cache[ key].nil?
      @cache[ key] = []
      factory = RGeo::Cartesian.factory(srid:get_srid(projection) , proj4:get_proj4(projection))
      @cache[source].each do |record|
          @cache[ key] << {name:     record[:name],
                           geometry: RGeo::Feature.cast(record[:geometry],factory:factory,project:true)}
      end
    end
    
    @cache[ key]
	end
	
  def copy_unchanged_bases( io)
    return if @output_file_bak.nil?
    copy = false
    IO.readlines( @output_file_bak).each do |line|
      if line[0..3] == 'key '
        if copy = @keys[line.chomp[4..-1]]
          copy['copied'] = true
        end
      end
      io.print line if copy
    end
  end
  
  def crawl_inwards( grid, dx, dy, limit)
    loop = true
    while loop
      loop = false
      
      (0...grid.size).each do |i|
        (0...grid[0].size).each do |j|
          loop |= crawl_inwards1( grid, i, j, i+1, j, dx, limit)
          loop |= crawl_inwards1( grid, i, j, i-1, j, dx, limit)
          loop |= crawl_inwards1( grid, i, j, i, j+1, dy, limit)
          loop |= crawl_inwards1( grid, i, j, i, j-1, dy, limit)
        end
      end
    end
  end
  
  def crawl_inwards1( grid, i0, j0, i1, j1, delta, limit)
    return if (i1 < 0) || (i1 >= grid.size)
    return if (j1 < 0) || (j1 >= grid[0].size)
    return if grid[i0][j0].nil? or (grid[i0][j0] >= limit)
    
    was = grid[i1][j1]
    if grid[i1][j1].nil?
      grid[i1][j1] = grid[i0][j0] + delta
    elsif (grid[i1][j1] < limit)
      grid[i1][j1] = min( grid[i1][j1], grid[i0][j0] + delta)
    end
    was != grid[i1][j1]
  end
  
  def create_grid( width, bounds)
    height = 1 + (width * (bounds[3] - bounds[1]) / (bounds[2] - bounds[0])).to_i
    grid = Array.new( width)
    grid.each_index do |column|
      grid[column] = Array.new(height)
    end
    grid
  end
  
  def default( parent, child, key)
    child[key] = parent[key] if child[key].nil?
  end
	
  def determine_centroid( polygons)
    bounds = [nil, nil, nil, nil]
    polygons.each do |polygon|
      polygon.each {|coord| point_bounds( coord, bounds)}
    end
    
    grid = create_grid( 100, bounds)
    
    polygons.each do |polygon|
      polygon.each_index do |i|
        draw_line( polygon[i-1], polygon[i], grid, bounds) if i > 0
      end
    end
    
    zero_from_edges( grid)
    null_non_zeroes( grid)
    crawl_inwards( grid, 1, 1, 100000)
    #dump_grid( grid)
    furthest_point( grid, bounds)
  end
  
  def draw_line( from, to, grid, bounds)
    f = draw_point( from, grid, bounds)
    t = draw_point( to, grid, bounds)
    
    return if (f[0] == t[0]) && (f[1] == t[1])
    npts = max( (t[0] - f[0]).abs, (t[1] - f[1]).abs)
    (0..npts).each do |i|
      point = draw_point( [from[0] + ((to[0] - from[0]) * i) / npts,
                           from[1] + ((to[1] - from[1]) * i) / npts],
                          grid, bounds)
      grid[point[0]][point[1]] = 1
    end
  end
  
  def draw_point( coord, grid, bounds)
    x = min( grid.size-1, (grid.size * ((coord[0] - bounds[0]) / (bounds[2] - bounds[0]))).to_i)
    y = min( grid[0].size-1, (grid[0].size * ((coord[1] - bounds[1]) / (bounds[3] - bounds[1]))).to_i)
    [x,y]
	end
  
  def dump_grid( grid)
    (0...(grid[0].size)).each do |j|
      print '|'
      (0...(grid.size)).each do |i|
        cell = grid[i][grid[0].size - 1 - j]
        if cell.nil?
          print ' '
        elsif cell > 9
          print '*'
        else
          print cell.to_i.to_s
        end
      end
      puts "|"
    end
  end
  
  def error( msg)
    @errors += 1
    puts "*** #{msg}"
  end
  
	def feature_bounds( defn, feature, resolution, bounds, found)
		feature_geometry( defn, feature) do |name, type, colour, coords|
			next if type != :outer
			if defn['includes'].nil? || defn['includes'].include?( name)
				found << name
				
				res_bounds = [nil, nil, nil, nil]
				coords.each {|coord| point_bounds( coord, res_bounds)}
				
				if ((res_bounds[2] - res_bounds[0]) >= resolution) || ((res_bounds[3] - res_bounds[1]) >= resolution)
					coords.each {|coord| point_bounds( coord, bounds)}
				end
			end
		end
	end
	
	def feature_data( feature)
    type = feature.class.to_s.split('::')[-1]
		if type == 'FeatureCollection'
			feature.each do |feat|
				feature_data( feat) do |name, geom|
					yield name, geom
				end
			end
		elsif type == 'Feature'
			name = feature_name( feature)
      return if name.nil?
      yield name, feature.geometry
    else
      raise "Unhandled feature type [#{type}]"
    end
  end
	
	def feature_geometry( defn, feature)
    feature.each do |record|
      name = record[:name]
			geom = record[:geometry]
			gtype = geom.geometry_type.type_name
			
			if gtype == 'LineString'
				yield name, :line, 'black', geom.coordinates
			elsif gtype == 'MultiPoint'
				yield name, :points, 'black', geom.coordinates
			elsif gtype == 'MultiPolygon'
				max_size = 0
				fill = @fills[name]
				geom.coordinates.each do |loop|
					max_size = max( max_size, polygon_size( loop[0]))
				end
				
				geom.coordinates.each do |loop|
					size = polygon_size( loop[0])
					yield ((size == max_size) ? name : nil), :outer, fill, loop[0]
					loop[1..-1].each do |polygon|
						yield name, :inner, 'white', polygon
					end
				end
			elsif gtype == 'Point'
				yield name, :points, 'black', [geom.coordinates]
			elsif gtype == 'Polygon'
				loop = geom.coordinates
				yield name, :outer, @fills[name], loop[0]
				loop[1..-1].each do |polygon|
					yield name, :inner, 'white', polygon
				end
			else
				raise "Unexpected geometry type #{gtype}"
			end
		end
	end
	
  def feature_name( feature)
      name = feature.properties['NAME']
      name = feature.properties['name'] if name.nil?
      if name.nil? or (name.strip == '')
        p feature.properties
        return nil
      end
      
      if @control['regexes']
        @control['regexes'].each do |rename|
          re = Regexp.new( "^#{rename['from']}$")
          name = rename['to'] if re =~ name
        end
      end
      
      if @control['renames']
        @control['renames'].each_pair do |from, to|
          name = to if from == name
        end
      end
      
      return nil if name == ''
      name
  end
  
	def flush( defn, svg)
		File.open( defn['output']+'.svg', 'w') do |io|
			svg.each do |line|
				io.puts line
			end
			io.puts "</svg>"
		end
	end
	
  def furthest_point( grid, bounds)
    x,y = 0,0
    
    (0...grid.size).each do |i|
      (0...grid[0].size).each do |j|
        x,y = i,j if grid[i][j] > grid[x][y]
      end
    end
  
    return [bounds[0] + x * (bounds[2] - bounds[0]) / grid.size,
            bounds[1] + y * (bounds[3] - bounds[1]) / grid[0].size]
  end
  
	def generate( defn, io)
		#background = get_geojson( defn['background'])  #JSON.parse( IO.read( defn['background']))
		bounds = get_geojson_bounds( defn, defn['background'], defn['includes'])
    return if bounds.nil?
    
    if ! defn['copied']
      io.puts "key #{defn['key']}"
      io.puts "projection #{defn['projection']}"
      render( defn, bounds, io)
		end
    
		if defn['children']
			defn['children'].each do |child|
        default( defn, child, 'margin')
        default( defn, child, 'projection')
				generate( child, io)
			end
		end
	end
	
	def get_geojson_bounds( defn, path, includes)
		data = convert( path, defn['projection'])
		res_bounds = [nil, nil, nil, nil]
		found = []
		feature_bounds( defn, data, 0, res_bounds, found)
		
		if not includes.nil?
			missing = (includes - found.uniq)
			if missing.size > 0
				error( "#{missing.join(' ')} not found in #{path}")
        return nil
			end
		end

		resolution = 0.01 * max( res_bounds[2] - res_bounds[0], res_bounds[3] - res_bounds[1])
		bounds = [nil, nil, nil, nil]
		feature_bounds( defn, data, resolution, bounds, found)
		margin = get_margin(defn) * max( bounds[2] - bounds[0], bounds[3] - bounds[1])
		[bounds[0]-margin,bounds[1]-margin,bounds[2]+margin,bounds[3]+margin]
	end
	
  def get_margin( defn)
    if m = /^(\d+)%$/.match( defn['margin'].to_s)
      return m[1].to_i * 0.01
    end
    raise "No valid margin found"
  end
  
  def get_proj4( projection)
    if m = /^EPSG:(\d+)$/.match( projection)
      return `curl http://www.spatialreference.org/ref/epsg/#{m[1]}/proj4/`
    end
    raise "Unexpected projection: #{projection}"
  end
  
  def get_srid( projection)
    if m = /^EPSG:(\d+)$/.match( projection)
      return m[1].to_i
    end
    raise "Unexpected projection: #{projection}"
  end
  
	def make_pastel( i)
		sprintf( '%2x', 255 - 20 * i)
	end
	
	def make_pastels
		pastels = []
		(0..4).each do |i|
			(0..4).each do |j|
				(0..4).each do |k|
					pastels << "##{make_pastel(i)}#{make_pastel(j)}#{make_pastel(k)}"
				end
			end
		end
		pastels.shuffle
	end
	
	def max( v0, v1)
		return v1 if v0.nil?
		return v1 if v1 > v0
		v0
	end

	def min( v0, v1)
		return v1 if v0.nil?
		return v1 if v1 < v0
		v0
	end

  def null_non_zeroes( grid)
    (0...grid.size).each do |i|
      (0...grid[0].size).each do |j|
        grid[i][j] = 1000 if grid[i][j] != 0
      end
    end
  end

	def pastel_fill
		@pastel_index = 0 if @pastel_index >= @pastels.size
		fill = @pastels[@pastel_index]
		@pastel_index += 1
		fill
	end
	
	def point_bounds( coord, b)
		b[0] = min( b[0], coord[0])
		b[1] = min( b[1], coord[1])
		b[2] = max( b[2], coord[0])
		b[3] = max( b[3], coord[1])
	end
	
  def point_multiple( points, polygon, first)
    coord = polygon[first]
    key = "#{coord[0]},#{coord[1]}"
    points[key] == :multiple
  end
  
	def polygon_centroid( polygon, centroid)
		polygon[0...-1].each do |coord|
			centroid[0] += coord[0]
			centroid[1] += coord[1]
			centroid[2] += 1
		end
	end
	
	def polygon_size( coords)
		bounds = [nil, nil, nil, nil]
		coords.each {|coord| point_bounds( coord, bounds)}
		(bounds[2] - bounds[0]) * (bounds[3] - bounds[1])
	end
	
  def remove_duplicates( lines)
    counts = Hash.new {|h,k| h[k] = 0}
    edges = {}
    
    lines.each do |l|
      key0 = "#{l[0][0]},#{l[0][1]} #{l[1][0]},#{l[1][1]}"
      key1 = "#{l[1][0]},#{l[1][1]} #{l[0][0]},#{l[0][1]}"
      
      if key0 < key1
        counts[key0] += 1
        edges[key0] = l
      else
        counts[key1] += 1
        edges[key1] = l
      end
    end
    
    lines = []
    counts.each_pair do |key, count|
      if (count % 2) != 0
        lines << edges[key]
      end
    end
    
    lines
  end
  
	def render( defn, bounds, io)
#		reduce( defn['background'], bounds, '/tmp/data.json')
		json = convert( defn['background'], defn['projection'])
		name_polygons = Hash.new {|h,k| h[k] = []}
    
		feature_geometry( defn, json) do |name, type, colour, coords|
			next if not within_bounds( coords, bounds)
			
			if type == :inner
				svg_loop( coords, colour, io)
        name_polygons[name] << coords
			elsif type == :line
				svg_line( coords, io)
			elsif type == :outer
				svg_loop( coords, colour, io)
        name_polygons[name] << coords
			end
		end

    name_polygons.each_pair do |name, polygons|
      points = analyse_points( polygons)
      
      polygons.each do |polygon|
        render_perimeter( points, polygon, io)
      end

      centroid = determine_centroid( polygons)
			render_text_centre( name, centroid, io)
    end
    
    if defn['children']
      defn['children'].each do |child|
        feature = convert( child['background'], defn['projection'])
        feature_geometry( defn, feature) do |name, type, colour, coords|
          next if type != :outer
          if child['includes'].nil? || child['includes'].include?( name)
            render_hotspot( child['output'], coords, io)
          end
        end
      end
    end
	end
	
  def render_perimeter( points, polygon, io)
    first = 0
    
    while (first < polygon.size) do
      while ((first < polygon.size) && point_multiple( points, polygon, first))
        first += 1
      end
      
      return if first >= (polygon.size - 1)
      
      last = first
      
      while ((last < polygon.size) && (! point_multiple( points, polygon, last)))
        last += 1
      end
      
      svg_line( polygon[max(0,first-1)..min(polygon.size-1,last+1)], io)
      first = last
    end
  end
	
	def render_hotspot( link, coords, io)
    io.puts "link #{link}"
    render_coordinates( coords, io)
	end
  
	def render_text_centre( name, centroid, io)
    io.puts "text #{name}"
		x, y = * centroid
    render_coordinates( [centroid], io)
	end

#	def render_text_centre( name, centroid, bounds, svg, dims)
#		x, y = svg_xy( centroid[0], centroid[1], bounds, dims)
#		svg << <<"TEXT"
#<text x="#{x}" y="#{y}" fill="black" text-anchor="middle">#{name}</text>
#TEXT
#	end

	def run( output)
    assign_keys( @control)
    File.open( output, 'w') do |io|
      io.puts "root #{@control['key']}"
      copy_unchanged_bases( io)
      generate( @control, io)
    end
	end
	
	def svg_line( line, io)
    io.puts "line"
    render_coordinates( line, io)
	end
	
	def svg_loop( loop, fill, io)
    io.puts "polygon #{fill}"
    render_coordinates( loop, io)
	end
	
	def within_bounds( coords, bounds)
		coords.each do |xy|
			x, y = * xy
			return true if (x >= bounds[0]) && (x <= bounds[2]) && (y >= bounds[1]) && (y <= bounds[3])
		end
		false
	end
  
  def zero_from_edges( grid)
    (0...grid.size).each do |i|
      grid[i][0] = 0 if grid[i][0].nil?
      grid[i][-1] = 0 if grid[i][-1].nil?
    end
    
    (0...grid[0].size).each do |i|
      grid[0][i] = 0 if grid[0][i].nil?
      grid[-1][i] = 0 if grid[-1][i].nil?
    end
    
    crawl_inwards( grid, 0, 0, 0.5)
  end
end

r = Generator.new( ARGV[0], ARGV[1])
r.run( ARGV[1])
