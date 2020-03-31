=begin
	Find links in website articles
=end

require 'yaml'

class LinkFinder
	ARTICLES='/Users/peter/Website/articles'
	DATABASE='/Users/peter/Website/data/website.sqlite'
	LAST_CHECKED='/Users/peter/Website/data/last_checked.yaml'
	TABLES={'dramas'=>['name','url'],
			'films'=>['name','url']}
	MAX_ERRS = 5
	
	def initialize
		@links = Hash.new {|h,k| h[k] = []}
	end

	def find_links( from = ARTICLES)
		YAML.load( File.open( ARTICLES + "/links.yaml")).each_pair do |link, url|
			@links[url] << "File: #{ARTICLES}/links.yaml, Name: #{link}"
		end

		scan_articles( from) do |f|
			lines = IO.readlines( f)
			lines.each_index do |i|
				line = lines[i]

				if /\.md$/ =~ f
					while m = /\]\((http[^\]]*)\)(.*)$/.match( line)
						@links[m[1]] << "File: #{f}, Line: #{i+1}"
						line = m[2]
					end
				else
					while m = /^(.*)\[(http\S*)\s(.*)$/.match( line)
						@links[m[2]] << "File: #{f}, Line: #{i+1}"
						line = m[1] + m[3]
					end
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

	def save_links( path)
		File.open( path, 'w') do |io|
			io.puts @links.to_yaml
		end
	end

	def scan_articles( dir)
		if File.directory?( dir)
			Dir.entries( dir).each do |f|
				next if /^\./ =~ f
				scan_articles( dir + '/' + f) {|article| yield article}
			end
		elsif /\.(txt|md)$/ =~ dir
			yield dir
		end
	end
end

lc = LinkFinder.new
#p lc.check_link( 'https://www.norwich.gov.uk/')
#raise 'Testing'
lc.find_links
lc.save_links( ARGV[0])
