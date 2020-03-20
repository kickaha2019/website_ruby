=begin
  Article.rb

  Represent article for HTML generation
=end

require 'fileutils'
require 'content_start'
require 'image'

class Article
  attr_accessor :content_added, :images, :sink_filename, :content

  class BackstopIcon < Image
    def initialize( sink)
      super( nil, sink, nil, nil, nil, 0)
    end

    def prepare_thumbnail( width, height, bw)
      return @sink, width, height
    end

    def scaled_height( dim)
      dim[1]
    end
  end

  def initialize( source, sink)
    @source_filename = source
    @sink_filename   = sink
    @seen_links      = {}
    @content         = []
    @children        = []
    @children_sorted = true
    @images          = []
    @icon            = nil
    @errors          = []

    add_content( ContentStart.new)

    sels = source.split( /[\/\.]/)
    set_title( ((sels[-2] != 'index') ? sels[-2] : sels[-3]))
  end

  def add_child( article)
    if children? && (@children[0].class != article.class)
      error( 0, 'Mixed children both links and articles')
    end
    unless article.is_a?( Link)
      @children_sorted = false
    end
    @children << article
  end

  def add_content( block)
    @content << block
  end

  def add_image( compiler, lineno, image, caption)
    @images << describe_image( compiler, lineno, image, caption)
  end

  def add_text_line( lineno, line, sep, lines)
    return if line == ""
    if i = line.index( "[")
      add_text_line( lineno, line[0..(i-1)], "", lines) if i > 0
            line = line[(i+1)..-1]
      if j = line.index( "]")
                if j > 0
                    lines << HTMLPageLink.new( self, lineno, line[0..(j-1)])
                    if (j+1) >= line.size
                        lines << HTMLPageTextLine.new( self, lineno, sep)
                    else
                        add_text_line( lineno, line[(j+1)..-1], sep, lines)
                    end
                else
                    error( lineno, "Empty link")
                end
      else
        error( lineno, "Mismatched []")
      end
    elsif line.index( "]")
      error( lineno, "Mismatched []")
    else
      line = encode_special_chars( line)
      while m = /^([^']*)''([^']*)''(.*)$/.match( line)
        line = m[1] + "<B>" + m[2] + "</B>" + m[3]
      end
      lines << HTMLPageTextLine.new( self, lineno, line + sep)
    end
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

  def describe_image( compiler, lineno, image_filename, caption)
    if /[\["\|<>]/ =~ caption
      error( lineno, "Image caption containing special character: " + caption)
      caption = nil
    end

    # caption = "#{source_filename}:#{lineno}" unless caption
    fileinfo = compiler.fileinfo( image_filename)
    info = nil
    ts = File.mtime( image_filename).to_i

    if File.exist?( fileinfo)
      info = IO.readlines( fileinfo).collect {|line| line.chomp.to_i}
      info = nil unless info[0] == ts
    end

    unless info
      dims = get_image_dims( lineno, image_filename)
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
               caption,
               info[1],
               info[2],
               lineno)
  end

  def error( lineno, msg)
    @errors << [@source_filename, lineno, msg]
  end

  def get_image_dims( lineno, filename)
    #raise filename # DEBUG CODE
    if not system( "sips -g pixelHeight -g pixelWidth -g orientation " + filename + " >sips.log")
      error( lineno, "Error running sips on: " + filename)
      nil
    else
      w,h,flip = nil, nil, false

      lines = IO.readlines( "sips.log")

      abs_path = lines[0].chomp.split('/')
      rel_path = filename.split('/')

      rel_path.each_index do |i|
        next if /^\./ =~ rel_path[i]
        if abs_path[i - rel_path.size] != rel_path[i]
          error( lineno, "Case mismatch for image name [#{filename}]")
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
        error( lineno, "Not a valid image file: " + filename)
        nil
      end
    end
  end

  def has_much_content?
    text_chars = 0
    @content.each {|item| text_chars += item.text_chars}
    text_chars > 80
  end

  def has_picture_page?
    return false if @images.size == 0
    return true if (@images.size >= 2) && has_much_content?
    return true if @children.size > 0
    false
  end

  def icon
    return @icon if @icon
    return @images[0] if @images.size > 0

    children.each do |child|
      if icon = child.icon
        return icon
      end
    end

    nil
  end

  def index( parents, html, pictures)
    wrap = true
    @content.each do |item|
      wrap = false unless item.wrap?
    end

    if @children.size > 0
      to_index = children
      error( 0, 'Some content does not wrap but has children') unless wrap
    else
      to_index = siblings( parents) # .select {|a| a != self}
    end

    if to_index.size == 0
      html.no_indexes
      return
    end
    html.small_no_indexes unless wrap

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
    image.prepare_images( dims, :prepare_thumbnail, page == self) do |file, w, h, sizes|
      html.add_index( file,
                      w, h,
                      sizes,
                      (page == self) ? nil : page.sink_filename,
                      prettify( page.title))
    end
  end

  def index_using_images( to_index, html)
    dims = html.dimensions( 'icon')
    scaled_dims = []
    backstop = BackstopIcon.new( html.sink_filename( "/resources/down_cyan.png"))
    backstop_bw = BackstopIcon.new( html.sink_filename( "/resources/down_bw.png"))

    dims.each do |dim|
      min_height = 20000

      to_index.each do |child|
        icon = child.icon ? child.icon : backstop
        height = icon.scaled_height( dim)
        min_height = height if height < min_height
      end

      scaled_dims << [dim[0], min_height]
    end

    to_index.each do |child|
      icon = child.icon ? child.icon : ((child == self) ? backstop_bw : backstop)
      index_resource( html, child, icon, scaled_dims)
    end

    (0..7).each {html.add_index_dummy}
  end

  def name
    if m = /(^|\/)([^\/]*)\.txt/.match( @source_filename)
      m[2]
    else
      @source_filename.split( "/")[-1]
    end
  end

  def picture_sink_filename
    m = /^(.*)\.[a-zA-Z]*$/.match( @sink_filename)
    m[1] + '_pictures.html'
  end

  def prepare( compiler)
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

  def prepare_source_images( html, do_caption)
    html.small_no_indexes
    html.start_div( 'gallery t1')

    dims = html.dimensions( 'image')
    @images.each do |image|
      image.prepare_images( dims, :prepare_source_image) do |file, w, h, sizes|
        html.image( file, w, h, image.caption, sizes)
      end
      html.add_caption( image.caption) if do_caption && image.caption
    end

    html.end_div
  end

  def prettify( name)
    HTML.prettify( name)
  end

  def report_errors( compiler)
    @errors.each {|err| compiler.error( * err)}
  end

  def set_date( t)
    @date = t if @date.nil?
  end

  def set_icon( compiler, lineno, path)
    if @icon.nil?
      if not File.exists?( path)
        error( 0, "Icon #{path} not found")
      else
        @icon = describe_image( compiler, lineno, path, nil)
      end
    end
  end

  def set_php
    return if /\.php$/ =~ @sink_filename
    if m = /^(.*)\.html$/.match( @sink_filename)
      @sink_filename = m[1] + '.php'
    else
      error( 0, 'Unable to set page to PHP')
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

  def to_pictures( parents, html)
    html.start_page( html.title)
    html.breadcrumbs( parents + [self], 'Pictures', false)
    html.start_div( 'payload content')
    index( parents, html, false)
    prepare_source_images( html, true)
    html.end_div
    html.end_page
  end

  def to_html( parents, html)
    html.start_page( html.title)

    @content.each do |item|
      item.process( self, parents, html)
    end

    if (@images.size > 1) && (! has_picture_page?)
      prepare_source_images( html, true)
    end

    dims = html.dimensions( 'icon')
    @images.each_index do |i|
      next if i >= html.floats.size
      @images[i].prepare_images( dims, :prepare_source_image) do |image, w, h, sizes|
        html.add_float( image, w, h, sizes, @images[i].caption, i)
      end
    end

    if @content.size > 1
      html.end_div
    end
    html.end_div
    html.end_page
  end

  def validate_anchor( compiler, lineno, link)
    if ! compiler.is_anchor_defined?(link)
      error( lineno, "Unknown anchor link: #{link}")
    end
  end
end
