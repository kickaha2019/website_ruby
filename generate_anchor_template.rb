#
# Generate templated markdown for anchors
#
# Command line:
#   Directory containing website definition
#   Template for markdown file
#   Output filename
#
# -------------------------------------------------------
#
require 'json'
require 'yaml'
require 'rexml/document'
require 'rexml/xpath'

class GenerateAnchorTemplate
	def initialize
    @anchors = Hash.new {|h,k| h[k] = {lat:nil, lon:nil, links:[], used:false}}
	end

  def check_all_anchors_defined
    @anchors.each_pair do |name, info|
      raise "Anchor #{name} not defined" unless info[:lat]
    end
  end

  def check_all_anchors_used
    @anchors.each_pair do |name, info|
      raise "Anchor #{name} not used" unless info[:used]
    end
  end

  def find_anchors( path, target)

    # Loop over source files
    Dir.entries( path).each do |file|
      next if /^\./ =~ file
      path1 = path + "/" + file

      if File.directory?( @source + path1)
        find_anchors(path1, target)
      elsif /\.kml\.xml$/ =~ file
        parse_kml_xml( @source + path1)
      elsif m = /^(.*)\.yaml$/.match( file)
        defn = YAML.load( IO.read( path1))
        if defn['anchors']
          defn['anchors'].each do |anchor|
            @anchors[anchor][:links] << relative_path( target, path1.gsub(/\.yaml/, '.html'))
          end
        end
      end
    end
  end

  def generate( template)
    erb = ERB.new( IO.read( template))
    erb.result( Bound.new( {anchors:@anchors}).get_binding)
  end

  def parse_kml_xml( path)
    doc = REXML::Document.new IO.read( path)
    REXML::XPath.each( doc, "//Placemark") do |place|
      entry = @anchors[ place.elements['name'].text.strip]
      coords = place.elements['Point'].elements['coordinates'].text.strip.split(',')
      entry[:lat] = coords[1].to_f
      entry[:lon] = coords[0].to_f
    end
  end

  def relative_path( from, to)
    from = from.split( "/")
    from = from[0...-1] if /\.(html|php|txt)$/ =~ from[-1]
    to = to.split( "/")
    while (to.size > 0) and (from.size > 0) and (to[0] == from[0])
      from = from[1..-1]
      to = to[1..-1]
    end
    rp = ((from.collect { ".."}) + to).join( "/")
    (rp == '') ? '.' : rp
  end
end

gam = GenerateAnchorTemplate.new
gam.find_anchors( ARGV[0], ARGV[2])
gam.check_all_anchors_used
gam.check_all_anchors_defined
File.open( ARGV[2], 'w') do |io|
  io.print gam.generate( ARGV[1])
end
