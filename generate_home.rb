=begin
	generate_home.rb

	Generate home page for website
=end

File.open( ARGV[1], 'w') do |io|
	IO.readlines( ARGV[0]).each do |line|
		line = line.chomp
		
		# Patch URL references
		line.gsub!( /(href|src|HREF|SRC)="[^"]*"/) do |address|
			if /"\.\./ =~ address
				address.gsub!( '"..', '"Articles')
			elsif /"http/ =~ address
				address
			else
				address.gsub!( '="', '="Articles/')
			end
		end
		
		io.puts( line)
	end
end
