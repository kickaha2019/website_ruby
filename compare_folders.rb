def list_dir( path)
	files = []
	d = Dir.new( path)
	d.each { |file|
		next if /^\./ =~ file
		raise "Error" if file == "." or file == ".."
		next if file == ".DS_Store"
		if / / =~ file
			raise "Spaces in name at #{path}/#{file}"
		end
		files.push( file)
	}
	d.close	
	files
end

$errors = 0
def error( msg)
	$errors += 1
	puts( '*** ' + msg)
end

def compare_folder( path1, path2, weak)
	if File.directory?( path1)
		files1 = list_dir( path1)
		files2 = list_dir( path2)
		
		(files1 - files2).each do |f|
			error( "File #{f} missing in #{path2}")
		end
		
		(files2 - files1).each do |f|
			error( "File #{f} added in #{path2}")
		end
		
		files1.each do |f|
			if File.exists?( path2 + '/' + f)
				compare_folder( path1 + '/' + f, path2 + '/' + f, weak)
			end
		end
	elsif /\.(html|php|js)$/ =~ path1 && weak
		data1 = read_weak( path1)
		data2 = read_weak( path2)
		if data1 != data2
			error( "File #{path2} mismatch to #{path1}")
		end
	else
		if IO.read( path1, nil, nil, mode: 'rb') != IO.read( path2, nil, nil, mode: 'rb')
			error( "File #{path2} mismatch to #{path1}")
		end
	end
end

def read_weak( path)
	data = IO.readlines( path).join
	data.downcase.gsub( ' ', '').gsub( "\n", '')
end

compare_folder( ARGV[0], ARGV[1], ARGV[2] == 'weak')
puts "#{$errors} errors"
