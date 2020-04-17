=begin
	Link.rb

	Represent link for HTML generation
=end

class Link
  attr_reader :date, :icon, :sink_filename, :title

	def initialize( article, link, title=nil)
		@article       = article
		@link          = link
		@title         = title
		@blurb         = nil
		@date          = nil
    @icon_source   = nil
    @sink_filename = nil
	end

	def blurb
		@blurb
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

	def icon
		@icon_source.icon
	end

	def prepare( compiler, parents)
		bound, error = compiler.lookup( @link)
		if bound
			@blurb         = bound.blurb
			@date          = bound.date
			@icon_source   = bound
			@sink_filename = bound.sink_filename
			@title         = bound.title unless @title
		else
			@article.error( 0, error)
		end
	end
end
