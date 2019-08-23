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
	TABLES={'dramas'=>['name','url'],
			'films'=>['name','url']}
	MAX_ERRS = 30
	
	def initialize
		@links = Hash.new {|h,k| h[k] = []}
    @info  = Hash.new {|h,k| h[k] = {}}
	end

	def check_link( url, info)
    escaped = CGI::escapeHTML( url)
		#return "#{url}: Bad characters" if /["'`' ]/ =~ url
		#puts "check_link: #{url}"
		headers = `curl -s -I '#{escaped}'`.split("\n")
		if headers.size == 0
			return nil if info['no_headers']
			return "#{url}: No headers"
		end
		
		code = headers[0].split(' ')[1]
    expected_responses = info['response'] ? info['response'].to_s.split(' ') : []
		return nil if expected_responses.include?( code)
		
		if ['301', '302'].include?( code)
			location = '???'
			headers[1..-1].each do |header|
				if m = /^Location: (.*)$/.match( header.chomp)
					location = m[1]
				end
			end
			
			return nil if /^\// =~ location
			return nil if /^\?/ =~ location
			return nil if location[0..url.size] == (url + '?')
			return nil if location == info['redirect']
      return nil if location == url
			return "#{url}\n    moved to\n    #{location}\n"
		end

		if not ['200','302','503'].include?( code)
			return "#{url}\n    response code [#{code}]\n"
		end
		
		nil
	end
	
	def check_links
		n_errs = 0
		
		YAML.load( File.open( ARTICLES + "/links.yaml")).each_pair do |link, info|
      @info[info['url']] = info
			error = check_link( info['url'], info)
			
			if not error.nil?
				n_errs += 1
				puts '***** ' + link + "\n    " + error
			end
		end
		
		@links.each_pair do |url, origins|
      error = nil
      begin
			  error = check_link( url, @info[url])
      rescue Exception => bang
        p [url, @info[url]]
        error = bang.message
      end
			
			if not error.nil?
				n_errs += 1
				origins.each {|o| puts "***** #{o}"}
				puts '    ' + error
			end
			
			if n_errs > MAX_ERRS
				puts "*** More than #{MAX_ERRS} errors"
				exit( 1)
			end
		end
	end
	
	def find_links
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

