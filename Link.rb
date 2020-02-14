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
	end

	def children
		return @bound.children if @bound
		[]
	end
	
	def children?
		return @bound.children? if @bound
		false
	end
	
	def date
		return @bound.date if @bound
		nil
	end

	def has_content?
		return @bound.has_content?
	end

	def icon
		return @bound.icon if @bound
		nil
	end

	def match_article_filename( article, re, matches)
		matches << article if re =~ article.source_filename
		article.children.each do |child|
			match_article_filename( child, re, matches) if child.is_a?( Article)
		end
	end

	def prepare( root_article)
		re = Regexp.new( "(^|/)#{@link}(\.txt|/index.txt)")
		matches = []
		match_article_filename( root_article, re, matches)

		if matches.size < 1
			@article.error( @lineno, "Link not found")
		elsif matches.size > 1
			@article.error( @lineno, "Ambiguous link")
		else
			@bound = matches[0]
		end
	end

	def sink_filename
		return @bound.sink_filename if @bound
		"???"
	end
	
	def title
		return @title if @title
		return @bound.title if @bound
		"???"
	end
end
