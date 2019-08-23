=begin
	synch_check_log.rb

	Check log file from running sftp or ssh script synching local site to remote site
=end

ignores = []
IO.readlines( ARGV[0]).each do |line|
	ignores << Regexp.new( line.chomp)
end

IO.readlines( ARGV[1]).each do |line|
	ok = false
	ignores.each do |ignore|
		ok = true if ignore =~ line.chomp
	end
	
	if not ok
		puts "Error line: #{line.chomp}"
		exit 1
	end
end
