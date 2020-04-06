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

	def prepare( compiler, parents)
		bound, error = compiler.find_article( @link)
		if bound
			@date          = bound.date
			@icon          = bound.icon
			@sink_filename = bound.sink_filename
			@title         = bound.title unless @title
		else
			@article.error( 0, error)
		end
	end
end
