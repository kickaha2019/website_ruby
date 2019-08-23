def scan( dir)
	has_txts = false
	
	Dir.entries( dir).each do |f|
		next if /^\./ =~ f
		next if f == 'parameters.txt'
		has_txts = true if /\.txt$/ =~ f
		dir1 = dir + '/' + f
		scan( dir1) if File.directory?( dir1)
	end
	
	if has_txts && (! File.exist?( dir + '/index.txt'))
		puts "*** #{dir}"
	end
end

scan( '/Users/peter/Website/Articles')
