class Commands
	@@default_date = Time.gm( 1970, "Jan", 1)
	@@gallery_index = 0

	def Anchor( article, lineno, entry)
		if entry.size < 1
			article.error( lineno, "No entries for anchor")
		else
			entry.each do |link|
				article.validate_anchor( lineno, link)
			end
		end

		article.add_content do |parents, html|
			html.anchor
		end
	end

	def Centre( article, lineno, entry)
		article.ensure_no_float
		add_image( article, lineno, entry, 'centre', 'CENTRE', false)
	end
	
	def Code( article, lineno, entry)
		article.ensure_no_float
		if entry.size < 1
			article.error( lineno, "No lines for code")
		else
			article.add_content do |parents, html|
				html.code( entry) do |error|
					article.error( lineno, error)
				end
			end
		end
	end
	
	def Date( article, lineno, entry)
		article.ensure_no_float
		if entry.size != 1
			article.error( lineno, "Dates should have one line in the entry")
			return
		end
		
		t = convert_date( article, lineno, entry[0])
		article.set_date( t)
		
		article.add_content do |parents, html|
			html.date( t) do |error|
				article.error( lineno, error)
			end
		end
	end
	
	def Gallery( article, lineno, entry)
		article.ensure_no_float
		article.add_content do |parents, html|
			html.start_gallery
		end
	
		@@gallery_index += 1
		entry_blocks( entry, lineno) do |block, block_lineno|
			article.add_content do |parents, html|
				html.start_cell
				html.start_div
			end
			add_image( article, block_lineno, block, 'gallery_cell', 'GALLERY', false, @@gallery_index)
			article.add_content do |parents, html|
				html.end_div
				html.start_div
				html.write( block[1]) if not block[1].nil?
				html.end_div
				html.end_cell
			end
		end
		
		article.add_content do |parents, html|
			html.end_gallery
		end
	end
	
	def Heading( article, lineno, entry)
		article.ensure_no_float

		if entry.size != 1
			article.error( lineno, "Heading takes one line")
		else
			article.add_content do |parents, html|
				html.heading( entry[0])
			end
		end
	end

	def HTML( article, lineno, entry)
		article.ensure_no_float

		if entry.size < 1
			article.error( lineno, "No lines for HTML")
		else
			article.add_content do |parents, html|
				html.html( entry) do |error|
					article.error( lineno, error)
				end
			end
		end
	end
	
	def Icon( article, lineno, entry)
		article.ensure_no_float

		if entry.size != 1
			article.error( lineno, "Icon takes one line for image filename")
		else
			path = entry[0]
			if /^\// =~ path
				article.set_icon( path)
			else
				path = abs_filename( article.source_filename, entry[0])
				article.set_icon( path)
				path = article.prepare_source_image( lineno, path)
			end
		end
	end
	
	def Left( article, lineno, entry)
		article.ensure_no_float
		add_image( article, lineno, entry, 'left', 'FLOAT', true)
	end
	
	def Link( article, lineno, entry)
		article.ensure_no_float
		if (entry.size < 1) || (entry.size > 2)
			article.error( lineno, "Links should have one or two lines in the entry")
			return
		end
		
		article.add_child( Link.new( article, lineno, * entry))
	end
	
	def PHP( article, lineno, entry)
		article.ensure_no_float
		article.set_php
		if entry.size < 1
			article.error( lineno, "No lines for code")
		else
			article.add_content do |parents, html|
				html.php( entry) do |error|
					article.error( lineno, error)
				end
			end
		end
	end

	def Right( article, lineno, entry)
		article.ensure_no_float
		add_image( article, lineno, entry, 'right', 'FLOAT', true)
	end
	
	def Table( article, lineno, entry)
		article.ensure_no_float
		article.add_content do |parents, html|
			html.start_table( article.get( "TABLE_CLASS"))
		end
	
		width = 1
		entry_lines( entry, lineno) do |line, line_lineno|
			w = line.split('|').size
			width = w if w > width
		end

		entry_lines( entry, lineno) do |line, line_lineno|
			article.add_content do |parents, html|
				html.start_table_row
				fields = line.split('|')
				fields.each do |field|
					html.start_table_cell
					html.write( field)
					html.end_table_cell
				end
				(fields.size...width).each do
					html.start_table_cell
					html.nbsp
					html.end_table_cell
				end
				html.end_table_row
			end
		end
		
		article.add_content do |parents, html|
			html.end_table
		end
	end
	
	def Text( article, lineno, entry)
		float = article.float

		if entry.size < 1
			article.error( lineno, "No lines for text")
		else
			article.add_content do |parents, html|
				html.text( parents, entry, float) do |error|
					article.error( lineno, error)
				end
			end
		end
	end
	
	def Title( article, lineno, entry)
		article.ensure_no_float
		if entry.size != 1
			article.error( lineno, "Title definition should be one line long")
		elsif /[\["\|&<>]/ =~ entry[0]
			article.error( lineno, "Title containing special character: " +	entry[0])
		else
			article.set_title( entry[0])
		end
	end
	
	def abs_filename( path, filename)
		return filename if /^\// =~ filename
		path = File.dirname( path)
		while /^\.\.\// =~ filename
			path = File.dirname( path)
			filename = filename[3..-1]
		end
		path + '/' + filename
	end
	
	def add_image( article, lineno, entry, css_class, type, float, gallery_index=nil)
		if entry.size < 1 or entry.size > 2
			article.error( lineno, "Bad image declaration")
			return
		end
		
		path = entry[0].strip
		if /^\// =~ path
			article.set_icon( path)
		else
			path = abs_filename( article.source_filename, path)
			article.set_icon( path)
			path = article.prepare_source_image( lineno, path)
		end

		if not File.exists?( path)
			article.error( lineno, "Image file not found: " + path)
			#raise "Image file not found"
			return
		end

		if entry.size == 2
			article.set_image_caption( lineno, path, [entry[1]])
		end
		
		article.add_image( float, lineno) do |parents, html|
			tw = article.get( type + '_WIDTH').to_i
			th = article.get( type + '_HEIGHT').to_i
			alt_text = article.get_image_caption( path)
			(w,h) = article.prepare_sink_image( lineno, path, tw, th)
			html.start_div( css_class)
			html.start_lightbox( path, alt_text, gallery_index)
			html.image( path, w, h, alt_text, float) do |error|
				article.error( lineno, error)
			end
			html.end_lightbox
			html.end_div
		end
	end
	
	def convert_date( article, lineno, text)
		day = -1
		month = -1
		year = -1
		
		text.split.each do |el|
			i = el.to_i
			if i > 1900
				year = i
			elsif (i > 0) && (i < 32)
				day = i
			else
				if i = ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"].index( el[0..2].downcase)
					month = i + 1
				end
			end
		end
		
		if (day > 0) && (month > 0) && (year > 0)
            Time.gm( year, month, day)
		else
			article.error( lineno, "Bad date [#{text}]")
			@@default_date
		end
	end

	def entry_blocks( entry, lineno)
		block_text = nil
		entry.each_index do |i|
			line = entry[i]
			if line == ''
				yield block_text, (lineno + i - 1) if block_text
				block_text = nil
				next
			end
			block_text = [] if not block_text
			block_text << line
		end
		yield block_text, (lineno + entry.size - 1) if block_text
	end
		
	def entry_lines( entry, lineno)
		entry.each_index do |i|
			yield entry[i], lineno+i-1
		end
	end
end
