=begin
  Article.rb

  Represent article for HTML generation
=end

require 'fileutils'
require 'image'
require "markdown.rb"
require 'utils'

class Article
  include Utils
  attr_accessor :content_added

  def initialize( source, sink)
    @source_filename = source
    @sink_filename   = sink
    @children        = []
    @children_sorted = true
    @icon            = nil
    @errors          = []
    @content         = []
  end

  def add_child( article)
    if children? && (@children[0].class != article.class)
      error( 'Mixed children both links and articles')
    end
    unless article.is_a?( Link)
      @children_sorted = false
    end
    @children << article
  end

  def add_content( item)
    @content << item
  end

  def blurb
    @content.each do |item|
      if item.is_a?( Blurb)
        return item.blurb
      end
    end
    nil
  end

  def children
    if not @children_sorted
      @children = sort( @children)
      @children_sorted = true
    end
    @children
  end

  def children?
    @children.size > 0
  end

  def date
    @content.each do |item|
      if item.is_a?( Date)
        return item.date
      end
    end
    nil
  end

  def error( msg)
    @errors << msg
  end

  def has_any_content?
    @content.each do |item|
      return true if item.page_content?
    end
    false
  end

  def has_gallery?
    @content.each do |item|
      return true if item.is_a?( Gallery)
    end
    false
  end

  def icon
    @content.each do |item|
      return item if item.is_a?( Icon)
    end

    @content.each do |item|
      return item if item.is_a?( Image)
      return item.image if item.is_a?( Inset)
      return item.first_image if item.is_a?( Gallery)
    end

    children.each do |child|
      if icon = child.icon
        return icon
      end
    end

    nil
  end

  def index( parents, html)
    if @children.size > 0
      to_index = children
    elsif has_gallery?
      to_index = []
    else
      to_index = siblings( parents) # .select {|a| a != self}
    end

    if no_index? || (to_index.size == 0)
      html.no_indexes
      return
    end

    html.small_no_indexes
    html.start_indexes

    if index_images?( to_index)
      index_using_images( to_index, html)
    else
      html.children( self, to_index)
    end

    html.end_indexes
  end

  def index_images?( articles)
    articles.each do |article|
      return false unless article.icon
    end

    true
  end

  def index_resource( html, page, image, dims)
    target = (page == self) ? nil : page.sink_filename
    alt_text = prettify( page.title)

    html.begin_index( target, (page == self) ? 'border_white' : '')
    html.add_blurb( page.blurb) unless (page == self) || page.blurb.nil?
    html.image( image, '', dims, :prepare_thumbnail)
    html.end_index( target, alt_text)
  end

  def index_using_images( to_index, html)
    dims = html.dimensions( 'icon')
    scaled_dims = get_scaled_dims( dims,
                                   to_index.collect do |child|
                                     child.icon
                                   end)

    to_index.each do |child|
      index_resource( html, child, child.icon, scaled_dims)
    end

    (0..7).each {html.add_index_dummy}
  end

  def name
    path = @source_filename.split( "/")
    (path[-1] == 'index') ? path[-2] : path[-1]
  end

  def no_index?
    @content.each do |item|
      return item.flag if item.is_a?( NoIndex)
    end
    false
  end

  def prepare( compiler, parents)
    @content.each do |item|
      item.prepare( compiler, self, parents)
    end
  end

  def report_errors( compiler)
    @errors.each {|err| compiler.error( @source_filename, err)}
  end

  def siblings( parents)
    return [] if parents.size == 0
    parents[-1].children
  end

  def sink_filename
    ext = 'html'
    @content.each do |item|
      ext = 'php' if item.is_a?( PHP)
    end
    @sink_filename.gsub( /html$/, ext)
  end

  def sort( articles)
    articles.sort do |a1,a2|
      t1 = a1.title
      t2 = a2.title

      # Numbers on front of titles win out in sorting
      if m1 = /^(\d+)(\D|$)/.match( t1)
        if m2 = /^(\d+)(\D|$)/.match( t2)
          m1[1].to_i <=> m2[1].to_i
        else
          -1
        end
      elsif m2 = /^(\d+)(\D|$)/.match( t2)
        1

      # Next try for dates
      elsif a1.date
        if a2.date
          a1.date <=> a2.date
        else
          -1
        end
      elsif a2.date
        1

      # Lastly case insensitive sort on titles
      else
        a1.title.downcase <=> a2.title.downcase
      end
    end
  end

  def source_filename
    @source_filename
  end

  def title
    @content.each do |item|
      return item.title if item.is_a?( Title)
    end
    path = @source_filename.split( "/")
    (path[-1] == 'index') ? path[-2] : path[-1]
  end

  def to_html( parents, html)
    html.start_page( parents[0] ? parents[0].title : title)
    html.breadcrumbs( parents, title, false) if parents.size > 0
    html.start_div( 'payload content')

    index( parents, html)

    if has_any_content?
      html.start_div( 'story t1')
    end

    @content.each do |item|
      item.to_html( html) do |err|
        error( err)
      end
    end

    if has_any_content?
      html.end_div
    end
    html.end_div
    html.end_page
  end
end
