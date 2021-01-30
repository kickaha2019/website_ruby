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
  attr_accessor :content_added, :images, :sink_filename, :blurb

  class BackstopIcon < Image
    def initialize( sink)
      super( nil, sink, nil, nil, nil)
    end

    def prepare_thumbnail( width, height)
      return @sink, width, height
    end

    def scaled_height( dim)
      dim[1]
    end
  end

  def initialize( source, sink)
    @source_filename = source
    @sink_filename   = sink
    @children        = []
    @children_sorted = true
    @images          = []
    @icon            = nil
    @errors          = []
    @markdown        = nil
    @date            = nil
    @blurb           = nil
    @no_index        = false

    set_title( name)
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

  def add_image( compiler, image, tag)
    @images << describe_image( compiler, image, tag)
  end

  def add_markdown( defn)
    @markdown = Markdown.new( defn)
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
    @date # ? @date : Time.gm( 1970, "Jan", 1)
  end

  def describe_image( compiler, image_filename, tag)
    fileinfo = compiler.fileinfo( image_filename)
    info = nil
    ts = File.mtime( image_filename).to_i

    if File.exist?( fileinfo)
      info = IO.readlines( fileinfo).collect {|line| line.chomp.to_i}
      info = nil unless info[0] == ts
    end

    unless info
      dims = get_image_dims( image_filename)
      info = [ts, dims[:width], dims[:height]]
      File.open( fileinfo, 'w') do |io|
        io.puts info.collect {|i| i.to_s}.join("\n")
      end

      to_delete = []
      sink_dir = File.dirname( compiler.sink_filename( image_filename))

      if File.directory?( sink_dir)
        Dir.entries( sink_dir).each do |f|
          if m = /^(.*)_\d+_\d+(\..*)$/.match( f)
            to_delete << f if image_filename.split('/')[-1] == (m[1] + m[2])
          end
        end

        to_delete.each {|f| File.delete( sink_dir + '/' + f)}
      end
    end

    Image.new( image_filename,
               compiler.sink_filename( image_filename),
               tag,
               info[1],
               info[2])
  end

  def error( msg)
    @errors << msg
  end

  def get_image_dims( filename)
    #raise filename # DEBUG CODE
    if not system( "sips -g pixelHeight -g pixelWidth -g orientation " + filename + " >/tmp/sips.log")
      error( "Error running sips on: " + filename)
      nil
    else
      w,h,flip = nil, nil, false

      lines = IO.readlines( "/tmp/sips.log")

      abs_path = lines[0].chomp.split('/')
      rel_path = filename.split('/')

      rel_path.each_index do |i|
        next if /^\./ =~ rel_path[i]
        if abs_path[i - rel_path.size] != rel_path[i]
          error( "Case mismatch for image name [#{filename}]")
          return nil
        end
      end

      lines[1..-1].each do |line|
        if m = /pixelHeight: (\d*)$/.match( line.chomp)
          h = m[1].to_i
        end
        if m = /pixelWidth: (\d*)$/.match( line.chomp)
          w = m[1].to_i
        end
      end

      if w and h
        {:width => w, :height => h}
      else
        error( "Not a valid image file: " + filename)
        nil
      end
    end
  end

  def get_scaled_dims( dims, images)
    scaled_dims = []

    dims.each do |dim|
      min_height = 20000

      images.each do |image|
        height = image.scaled_height( dim)
        min_height = height if height < min_height
      end

      scaled_dims << [dim[0], min_height]
    end

    scaled_dims
  end

  def has_any_content?
    ! @markdown.nil?
  end

  def has_much_content?
    text_chars = @markdown ? @markdown.text_chars : 0
    text_chars > 300
  end

  def icon
    return @icon if @icon
    return @markdown.first_image if @markdown && @markdown.first_image

    children.each do |child|
      if icon = child.icon
        return icon
      end
    end

    nil
  end

  def index( parents, html, pictures)
    if @children.size > 0
      to_index = children
    else
      to_index = siblings( parents) # .select {|a| a != self}
    end

    if @no_index || (to_index.size == 0)
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
    with, without = 0, 0

    articles.each do |article|
      if article.icon
        with += 1
      else
        without += 1
      end
    end

    with > without
  end

  def index_resource( html, page, image, dims)
    target = (page == self) ? nil : page.sink_filename
    alt_text = prettify( page.title)

    html.begin_index( target, (page == self) ? 'border_white' : '')
    html.add_blurb( page.blurb) unless (page == self) || page.blurb.nil?
    image.prepare_images( dims, :prepare_thumbnail) do |file, w, h, sizes|
      html.image( file, w, h, alt_text, sizes)
    end
    html.end_index( target, alt_text)
  end

  def index_using_images( to_index, html)
    dims = html.dimensions( 'icon')
    backstop = BackstopIcon.new( html.sink_filename( "/resources/down_cyan.png"))
    scaled_dims = get_scaled_dims( dims,
                                   to_index.collect do |child|
                                     child.icon ? child.icon : backstop
                                   end)

    to_index.each do |child|
      icon = child.icon ? child.icon : backstop
      index_resource( html, child, icon, scaled_dims)
    end

    (0..7).each {html.add_index_dummy}
  end

  def name
    path = @source_filename.split( "/")
    (path[-1] == 'index') ? path[-2] : path[-1]
    # if m = /(^|\/)([^\/]*)\.(txt|md)$/.match( @source_filename)
    #   m[2]
    # else
    #   @source_filename.split( "/")[-1]
    # end
  end

  def picture_rp
    picture_sink_filename.split('/')[-1]
  end

  def picture_sink_filename
    m = /^(.*)\.[a-zA-Z]*$/.match( @sink_filename)
    m[1] + '_pictures.html'
  end

  def prepare( compiler, parents)
    if @icon
      err = nil

      if /^\// =~ @icon
        path = @icon
      else
        path = abs_filename( @source_filename, @icon)
        if ! File.exists?( path)
          path, err = compiler.lookup( @icon)
        end
      end

      if err.nil? && File.exists?( path)
        @icon = describe_image( compiler, path, nil)
      else
        error( err ? err : "Icon #{@icon} not found")
        @icon = nil
      end
    end

    defn, @images = @images, []
    defn.each do |image|
      err = nil
      path = image['path'].strip
      unless /^\// =~ path
        path1 = abs_filename( @source_filename, path)
        if File.exists?( path1)
          path = path1
        else
          path, err = compiler.lookup( path)
        end
      end

      if err.nil? && File.exists?( path)
        if md = image['tag']
          md = Markdown.new( md)
          md.prepare( compiler, self)
        end
        add_image( compiler, path, md)
      else
        error( err ? err : ("Image file not found: " + image['path']))
      end
    end

    if @markdown
      @markdown.prepare( compiler, self)
    end
  end

  def prepare_name_for_index( text)
    len = text.size
    words = prettify( text).split( " ")
    if (len > MAX_INDEX_NAME_SIZE) and (words.size > 1)
      while ((len + 4) > MAX_INDEX_NAME_SIZE) and (words.size > 1)
        len -= (1 + words[-1].size)
        words = words[0..-2]
      end
      words << "..."
    end
    words.join( "&nbsp;")
  end

  def report_errors( compiler)
    @errors.each {|err| compiler.error( @source_filename, err)}
  end

  def set_blurb( b)
    @blurb = b
  end

  def set_date( t)
    @date = t if @date.nil?
  end

  def set_icon( path)
    @icon = path
  end

  def set_images( images)
    @images = images
  end

  def set_no_index
    @no_index = true
  end

  def set_php
    return if /\.php$/ =~ @sink_filename
    if m = /^(.*)\.html$/.match( @sink_filename)
      @sink_filename = m[1] + '.php'
    else
      error( 'Unable to set page to PHP')
    end
  end

  def set_title( title)
    @title = title
  end

  def siblings( parents)
    return [] if parents.size == 0
    parents[-1].children
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
    @title ? @title : "Home"
  end

  def to_html( parents, html)
    html.start_page( parents[0] ? parents[0].title : @title)
    html.breadcrumbs( parents, title, false) if parents.size > 0
    html.start_div( 'payload content')

    index( parents, html, images.size > 1)

    if has_any_content?
      html.start_div( 'story t1')
    end

    if has_any_content? && @date
      html.date( @date) do |err|
        error( err)
      end
    end

    @markdown.process( self, parents, html) if @markdown

    if has_any_content?
      html.end_div
    end
    html.end_div
    html.end_page
  end
end
