=begin
	Link.rb

	Represent link for HTML generation
=end

class Link
  attr_reader :date, :icon, :sink_filename, :title

	def initialize( article, lineno, link, title=nil)
		@article       = article
		@lineno        = lineno
		@link          = link
		@title         = title
    @date          = nil
    @icon          = nil
    @sink_filename = nil
	end

	def children
		[]
	end
	
	def children?
		false
	end

	def has_content?
		false
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
			bound          = matches[0]
      @date          = bound.date
      @icon          = bound.icon
      @sink_filename = bound.sink_filename
      @title         = bound.title unless @title
		end
	end
end
