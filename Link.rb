=begin
	Link.rb

	Represent link for HTML generation
=end

class Link
	def initialize( article, lineno, link, title=nil)
		@article  = article
		@lineno   = lineno
		@link     = link
		@title    = title
		@bound    = nil
		@binded   = false
	end
	
	def bind
		if not @binded
			@binded = true
			re = Regexp.new( "(^|/)#{@link}(\.txt|/index.txt)")
			matches = @article.match_article_filename( re)
			
			if matches.size < 1
				@article.error( @lineno, "Link not found")
			elsif matches.size > 1
				@article.error( @lineno, "Ambiguous link")
			else
				@bound = matches[0]
			end
		end
		@bound
	end
	
	def children
		return @bound.children if bind
		[]
	end
	
	def children?
		return @bound.children? if bind
		false
	end
	
	def date
		return @bound.date if bind
		nil
	end

	def has_content?
		return @bound.has_content?
	end

	def icon
		return @bound.icon if bind
		nil
	end
	
	def sink_filename
		return @bound.sink_filename if bind
		"???"
	end
	
	def title
		return @title if @title
		return @bound.title if bind
		"???"
	end
end
