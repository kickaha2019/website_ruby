=begin
	Check that each page in website reachable from index page
=end

class ValidateReachability
	MAX_ERRS = 50
	
	def initialize( args)
		@root = ARGV[0]
		@exclude = []
		@errors  = 0
		@reached = Hash.new {|h,k| h[k] = false}
		
		excluding = false
		args[1..-1].each do |arg|
			if arg == '--exclude'
				excluding = true
			elsif excluding
				@exclude << arg
			else
				raise "Bad argument [#{arg}] on command line"
			end
		end
	end
	
	def check_pages_reached
		check( @root)
	end
	
	def check( dir)
		@exclude.each do |exclude|
			return if dir == (@root + '/' + exclude)
		end
		
		if File.directory?( dir)
			Dir.entries( dir).each do |f|
				next if /^\./ =~ f
				check( dir + '/' + f)
			end
		elsif /\.(html|php)$/ =~ dir
			if not @reached[dir]
				@errors += 1
				if @errors <= MAX_ERRS
					puts "*** #{dir} not reached"
				end
			end
		end
	end
	
	def follow_links
		follow( @root + '/index.html')
	end
	
	def follow( page)
		return if @reached[page]
		@reached[page] = true
		#puts "... Scanning #{page}"
		
		IO.readlines( page).each do |line|
			next if /marker\.bindPopup/ =~ line
			offset = 0
			while m = / href="([^"]*\.(html|php))"/i.match( line, offset)
				if not /^http/ =~ m[1]
					page2 = File.dirname( page) + '/' + m[1]
					if File.exists?( page2)
						follow( File.absolute_path( page2))
					else
						@errors += 1
						puts "*** Bad link #{m[1]} on page #{page}"
					end
				end
				offset = m.offset(0)[1]
			end
		end
	end
	
	def report
		if @errors > 0
			puts "*** #{@errors} pages not reachable"
			exit 1
		else
			puts "*** All pages reachable"
		end
	end
end

vr = ValidateReachability.new( ARGV)
vr.follow_links
vr.check_pages_reached
vr.report

