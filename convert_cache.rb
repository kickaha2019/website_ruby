require 'yaml'

old = YAML.load( File.open( ARGV[0]))
atts = [:width, :height, :sink_filename, :sink_timestamp, :sink_width, :sink_height]
File.open( ARGV[1], 'w') do |io|
	io.puts "filename\ttimestamp\t" + atts.collect {|a| a.to_s}.join("\t")
	old.each_pair do |key, data|
		io.puts "#{key}\t" + atts.collect {|a| data[a].nil? ? '' : data[a]}.join("\t")
	end
end
