require 'anchor'
require 'code'
require 'date'
require 'heading'
require 'html_block'
require 'php'
require 'table_end'
require 'table_row'
require 'table_start'
require 'text'

class Commands
	@@default_date = Time.gm( 1970, "Jan", 1)
	@@gallery_index = 0

	def Anchor( compiler, article, lineno, entry)
		if entry.size < 1
			article.error( lineno, "No entries for anchor")
		else
			entry.each do |link|
				article.validate_anchor( compiler, lineno, link)
			end
		end

		article.add_content( Anchor.new)
	end

	def Code( compiler, article, lineno, entry)
		if entry.size < 1
			article.error( lineno, "No lines for code")
		else
			article.add_content( Code.new( entry))
		end
	end
	
	def Date( compiler, article, lineno, entry)
		if entry.size != 1
			article.error( lineno, "Dates should have one line in the entry")
			return
		end
		
		t = convert_date( article, lineno, entry[0])
		article.set_date( t)
		
		article.add_content( Date.new( t))
	end
	
	def Gallery( compiler, article, lineno, entry)
		entry_blocks( entry, lineno) do |block, block_lineno|
			add_image( compiler, article, block_lineno, block)
		end
	end
	
	def Heading( compiler, article, lineno, entry)
		if entry.size != 1
			article.error( lineno, "Heading takes one line")
		else
			article.add_content( Heading.new( entry[0]))
		end
	end

	def HTML( compiler, article, lineno, entry)
		if entry.size < 1
			article.error( lineno, "No lines for HTML")
		else
			article.add_content( HTMLBlock.new( entry))
		end
	end
	
	def Icon( compiler, article, lineno, entry)
		if entry.size != 1
			article.error( lineno, "Icon takes one line for image filename")
		else
			path = entry[0]
			if /^\// =~ path
				article.set_icon( compiler, lineno, path)
			else
				path = abs_filename( article.source_filename, entry[0])
				article.set_icon( compiler, lineno, path)
			end
		end
	end

	def Image( compiler, article, lineno, entry)
		Images( compiler, article, lineno, entry)
	end

	def Images( compiler, article, lineno, entry)
		Gallery( compiler, article, lineno, entry)
	end

	def Link( compiler, article, lineno, entry)
		if (entry.size < 1) || (entry.size > 2)
			article.error( lineno, "Links should have one or two lines in the entry")
			return
		end
		
		article.add_child( Link.new( article, lineno, * entry))
	end

	def List( compiler, article, lineno, entry)
		Table( compiler, article, lineno, entry, 'border list')
  end

	def PHP( compiler, article, lineno, entry)
		article.set_php
		if entry.size < 1
			article.error( lineno, "No lines for code")
		else
			article.add_content( PHP.new( entry))
		end
	end

	def Table( compiler, article, lineno, entry, style = 'border table')
		width = 1

		entry_lines( entry, lineno) do |line, line_lineno|
			w = line.split('|').size
			width = w if w > width
		end
		article.add_content( TableStart.new( style))

		entry_lines( entry, lineno) do |line, line_lineno|
			article.add_content( TableRow.new( line, width))
		end

		article.add_content( TableEnd.new)
	end
	
	def Text( compiler, article, lineno, entry)
		if entry.size < 1
			article.error( lineno, "No lines for text")
		else
			article.add_content( Text.new( entry))
		end
	end
	
	def Title( compiler, article, lineno, entry)
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
	
	def add_image( compiler, article, lineno, entry)
		if entry.size != 2
			article.error( lineno, "Bad image declaration")
			return
		end
		
		path = entry[0].strip
		unless /^\// =~ path
			path = abs_filename( article.source_filename, path)
		end

		if not File.exists?( path)
			article.error( lineno, "Image file not found: " + path)
			#raise "Image file not found"
			return
		end

		article.add_image( compiler, lineno, path, entry[1])
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
