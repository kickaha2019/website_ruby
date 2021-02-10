=begin
	Link.rb

	Represent link for HTML generation
=end

class Link
  attr_reader :date, :time, :icon, :sink_filename, :title

	def initialize( article, link, title=nil)
		@article       = article
		@link          = link
		@title         = title
		@blurb         = nil
		@time          = nil
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

	def error( message)
		@article.error( message)
	end

	def has_content?
		false
	end

	def icon
		@icon_source ? @icon_source.icon : nil
	end

	def prepare( compiler, parents)
		bound, error = compiler.lookup( @link)
		if bound
			@blurb            = bound.blurb
			@time             = bound.time
			@date             = bound.date
			@icon_source      = bound
			@sink_filename    = bound.sink_filename
			@title            = bound.title unless @title
		else
			@article.error( error)
		end
	end
end
