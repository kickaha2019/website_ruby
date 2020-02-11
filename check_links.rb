=begin
	Check links in website articles
=end

require 'net/http'
require 'uri'
require 'yaml'
require 'openssl'
require 'cgi'

class LinkChecker
	ARTICLES='/Users/peter/Website/articles'
	DATABASE='/Users/peter/Website/data/website.sqlite'
	LAST_CHECKED='/Users/peter/Website/data/last_checked.yaml'
	TABLES={'dramas'=>['name','url'],
			'films'=>['name','url']}
	MAX_ERRS = 5
	
	def initialize
		@links = Hash.new {|h,k| h[k] = []}
		@last_checked = {}
		@problems = {}

		if File.exist?( LAST_CHECKED)
			@last_checked = YAML.load( IO.read( LAST_CHECKED))
		end
	end

	def check_links
		@links.keys.each do |url|
			escaped = CGI::escapeHTML( url)
			#return "#{url}: Bad characters" if /["'`' ]/ =~ url
			#puts "check_link: #{url}"
			response = `curl -s -I '#{escaped}'`
			response.force_encoding( 'UTF-8')
			response.encode!( 'US-ASCII',
											  :invalid => :replace, :undef => :replace, :universal_newline => true)
			headers = response.split("\n")

			if headers.size == 0
				@problems[url] = 'No headers'
			else
				code = headers[0].split(' ')[1]
				if not ['200'].include?( code)
					@problems[url] = "Response code [#{code}]\n"
				end
			end
		end
	end
	
	def find_links
		YAML.load( File.open( ARTICLES + "/links.yaml")).each_pair do |link, url|
			@links[url] << "File: #{ARTICLES}/links.yaml, Name: #{link}"
		end

		scan_articles( ARTICLES) do |f|
			lines = IO.readlines( f)
			lines.each_index do |i|
				line = lines[i]
				while m = /^(.*)\[(http\S*)\s(.*)$/.match( line)
					@links[m[2]] << "File: #{f}, Line: #{i+1}"
					line = m[1] + m[2]
				end
			end
		end
		
		TABLES.each_pair do |table, columns|
			IO.popen( "sqlite3 #{DATABASE} \"select #{columns[0]}, #{columns[1]} from #{table}\"").readlines.each do |line|
				d = line.split('|').collect {|e| e.strip}
				if (d.size == 2) and (d[1] != '')
					@links[d[1]] << "Table: #{table}, #{columns[0]}=#{d[0]}"
				end
			end
		end
	end

	def report_errors( path)
		now = Time.now.to_i
		sorted = @problems.keys.sort_by do |url|
			@last_checked[url] ? @last_checked[url] : now
		end

		if sorted.size > MAX_ERRS
			sorted = sorted[0...MAX_ERRS]
		end

		File.open( path, 'w') do |io|
			io.puts "<html><body><center><table border=\"1\" cellpadding=\"2\">"
			sorted.each do |url|
				io.puts "<tr><td><a href=\"#{url}\">#{url}</a></td>"
				io.puts "<td>#{@problems[url]}</td>"
				@last_checked[url] = now
				io.puts "<td>#{@links[url].join('<br>')}</td></tr>"
			end
			io.puts "</table></center></body></html>"
		end

		if sorted.size > 0
			puts "\n#{@problems.size} errors in all"
		end
	end

	def save_last_checked
		File.open( LAST_CHECKED, 'w') do |io|
			io.print @last_checked.to_yaml
		end
	end

	def scan_articles( dir)
		if File.directory?( dir)
			Dir.entries( dir).each do |f|
				next if /^\./ =~ f
				scan_articles( dir + '/' + f) {|article| yield article}
			end
		elsif /\.txt$/ =~ dir
			yield dir
		end
	end
end

lc = LinkChecker.new
#p lc.check_link( 'https://www.norwich.gov.uk/')
#raise 'Testing'
lc.find_links
lc.check_links
lc.report_errors( ARGV[0])
lc.save_last_checked
