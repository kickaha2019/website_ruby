=begin
	bento_to_sqlite.rb

	Convert film data
=end

def column( row, name)
	index = row.index( name)
	raise "No column [#{name}] in file [#{file}]" if not index
	index
end

def sql_integer( text)
	return "null" if text.nil? or text == ""
	text.gsub(",","")
end

def sql_list( header, row, *fields)
	data = []
	fields.each do |field|
		next if row[field] != "1"
		data << header[field]
	end
	sql_string( data.join( " / "))
end

def sql_string( text)
	return "null" if text.nil? or text == ""
	#text = text.gsub("’", "'")
	#text = text.gsub("\xD5", "'")
	#puts text.bytes.to_a if /They Who/ =~ text
	text = text.split("'").join("''")
	"'" + text + "'"
end

def sql_year( text)
	return "null" if text.nil? or text == ""
	text.gsub(",","")
end

def convert_films( source, sink)
	source_text = IO.read( source)
	source_text.force_encoding( 'UTF-8')
	source_text = source_text.encode( 'US-ASCII',
									  :invalid => :replace,
									  :undef => :replace,
									  :universal_newline => true,
									  :replace => '"')
	
	rows = source_text.split(/(\n|\r)/).collect {|l| l.chomp.split("\t")}
	
	name    = column( rows[0], "Title")
	year    = column( rows[0], "Year")
	country = column( rows[0], "Country")
	genre   = column( rows[0], "Genre")
	dvd     = column( rows[0], "DVD")
	bd      = column( rows[0], "Blu-Ray")
	link    = column( rows[0], "Link (Value)")
	
	rows[1..-1].each do |row|
		next if sql_string(row[name]) == 'null'
		sql = <<"INSERT"
sqlite3 #{sink} "insert into films (name,year,country,genre,url,media) values (#{sql_string(row[name])},#{sql_year(row[year])},#{sql_string(row[country])},#{sql_string(row[genre])},#{sql_string(row[link])},#{sql_list(rows[0],row,dvd,bd)})"
INSERT
		if not system sql
			puts sql
			raise "sqlite error"
		end
	end
end

convert_films( ARGV[0], ARGV[1])
