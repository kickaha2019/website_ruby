=begin
  Article.rb

  Represent article for HTML generation
=end

require 'fileutils'
require 'content_start'

class Article
    attr_accessor :content_added, :images, :sink_filename, :content

    def initialize( source, sink, params, compiler)
    @source_filename = source
    @sink_filename = sink
    @params = params
    @compiler = compiler
    @seen_links = {}
    @content = []
    @children = []
    @children_sorted = false
    @images   = []
    @icon = nil

    add_content( ContentStart.new)

    sels = source.split( /[\/\.]/)
    set_title( ((sels[-2] != 'index') ? sels[-2] : sels[-3]))
  end

  def add_child( article)
    @children_sorted = false
    @children << article
  end

  def add_content( block)
    @content << block
  end

  def add_image( lineno, image, caption)
    @images << describe_image( lineno, image, caption)
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
      @children = sort( @children, get( "ORDER"))
      @children_sorted = true
    end
    @children
  end

  def children?
    @children.size > 0
  end

  def constrain_dims( tw, th, w, h)
    if w * th >= h * tw
      if w > tw
        h = (h * tw) / w
        w = tw
      end
    else
      if h > th
        w = (w * th) / h
        h = th
      end
    end

    return w, h
  end

  def create_directory( path)
    path = File.dirname( path)
    unless File.exist?( path)
      create_directory( path)
      Dir.mkdir( path)
    end
  end

  def date
    if @date.nil?
      return children[0].date if children?
    end
    @date # ? @date : Time.gm( 1970, "Jan", 1)
  end

  def describe_image( lineno, image_filename, caption)
    if /[\["\|<>]/ =~ caption
      error( lineno, "Image caption containing special character: " + caption)
      caption = nil
    end

    # caption = "#{source_filename}:#{lineno}" unless caption
    fileinfo = @compiler.fileinfo( image_filename)
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
      sink_dir = File.dirname( @compiler.sink_filename( image_filename))

      if File.directory?( sink_dir)
        Dir.entries( sink_dir).each do |f|
          if m = /^(.*)_\d+_\d+(\..*)$/.match( f)
            to_delete << f if image_filename.split('/')[-1] == (m[1] + m[2])
          end
        end

        to_delete.each {|f| File.delete( sink_dir + '/' + f)}
      end
    end

    {lineno:lineno, image:image_filename, caption:caption, width:info[1], height:info[2]}
  end

  def error( lineno, msg)
    @compiler.error( @source_filename, lineno, msg)
  end

  def get( name)
    raise "Parameter [#{name}] not set" if @params[name].nil?
    @params[ name]
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

  def has_content?
    @content.size > 0
  end

  def has_picture_page?
    return false if @images.size == 0
    return true if (@images.size >= 2) && (@content.size > 1)
    return true if children.size > 0
    false
  end

  def has_text?
    @has_text
  end

  def icon
    return @icon if @icon
    return nil unless index_images?
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

    if index_children? && (@children.size > 0)
      to_index = children
      error( 0, 'Some content does not wrap but has children') unless wrap
    else
      to_index = siblings( parents).select {|a| a.has_content? && (a != self)}
    end

    if to_index.size == 0
      html.no_indexes
      return
    end
    html.small_no_indexes unless wrap

    html.start_indexes

    if index_images?
      index_using_images( parents, html)
    else
      html.children( to_index)
    end

    html.end_indexes
  end

  def index_children?
    get( 'INDEX_CHILDREN').downcase != 'false'
  end

  def index_images?
    get( 'INDEX') == 'image'
  end

  def index_resource( html, page, image = nil)
    dims = @compiler.dimensions( 'icon')
    prepare_images(image, dims, :prepare_thumbnail) do |file, w, h, sizes|
      html.add_index( file,
                      w, h,
                      sizes,
                      page.sink_filename,
                      prettify( page.title))
    end
  end

  def index_using_images( parents, html)
    if index_children? && (@children.size > 0)
      children.each do |child|
        index_resource( html, child, child.icon)
      end
    else
      siblings( parents).select {|a| a.has_content?}.each do |sibling|
        index_resource( html, sibling, sibling.icon) unless sibling == self
      end
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

  def prepare( root_article)
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

  def prepare_source_image( info, width, height)
    w,h = constrain_dims( width, height, info[:width], info[:height])
    file = info[:image]
    imagefile = @compiler.sink_filename( file[0..-5] + "-#{width}-#{height}" + file[-4..-1])
    @compiler.record( imagefile)

    if not File.exists?( imagefile)
      create_directory( imagefile)

      if w < info[:width] or h < info[:height]
        cmd = ["scripts/scale.csh", file, imagefile, w.to_s, h.to_s]
        raise "Error scaling [#{file}]" if not system( cmd.join( " "))
      else
        FileUtils.cp( file, imagefile)
      end
    end

    return imagefile, w, h
  end

  def prepare_source_images( html, caption)
    html.small_no_indexes
    html.start_div( 'gallery t1')

    dims = @compiler.dimensions( 'image')
    @images.each do |image|
      prepare_images( image, dims, :prepare_source_image) do |file, w, h, sizes|
        html.image( file, w, h, image[:caption], sizes)
      end
      html.add_caption( image[:caption]) if caption && image[:caption]
    end

    html.end_div
  end

  def prepare_thumbnail( info, width, height)
    w,h = shave_thumbnail( width, height, info[:width], info[:height])
    file = info[:image]
    thumbfile = @compiler.sink_filename( file[0..-5] + "-#{width}-#{height}" + file[-4..-1])
    @compiler.record( thumbfile)

    if not File.exists?( thumbfile)
      cmd = ["scripts/thumbnail.csh"]
      cmd << file
      cmd << thumbfile
      [w,h,width,height].each {|i| cmd << i.to_s}
      raise "Error scaling [#{info[:image]}]" if not system( cmd.join( " "))
    end

    return thumbfile, width, height
  end

  def prepare_images( info, dims, prepare)
    backstop = @compiler.sink_filename( "/resources/down_cyan.png")
    sizes = ''
    (0...dims.size).each do |i|
      sizes = sizes + " size#{i}"
      if ((i+1) >= dims.size) || (dims[i][0] != dims[i+1][0]) || (dims[i][1] != dims[i+1][1])
        if info
          file, w, h = send( prepare, info, * dims[i])
        else
          file, w, h = backstop, * dims[i]
        end
        yield file, w, h, sizes
        sizes = ''
      end
    end
  end

  def prettify( name)
    HTML.prettify( name)
  end

  def set_date( t)
    @date = t if @date.nil?
  end

  def set_icon( lineno, path)
    if @icon.nil?
      if not File.exists?( path)
        error( 0, "Icon #{path} not found")
      else
        @icon = describe_image( lineno, path, nil)
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

  def shave_thumbnail( width, height, width0, height0)
    if ((width0 * 1.0) / height0) > ((width * 1.0) / height)
      # p [height0, width, height, height0 * (width * 1.0), height0 * (width * 1.0) / height]
      w = (height0 * (width * 1.0) / height).to_i
      x = (width0 - w) / 2
      return x, 0
    else
      h = (width0 * (height * 1.0) / width).to_i
      y = (height0 - h) / 2
      return 0, y
    end
  end

  def siblings( parents)
    return [] if parents.size == 0
    parents[-1].children
  end

  def sort( articles, order)
    ascending = true
    ascending, order = false, order[0...-1] if order[-1] == '-'
    return articles if order == 'None'

    articles.sort do |a,b|
      a, b = b, a if not ascending

      if order == "Date"
        if a.date.nil? and b.date.nil?
          a.title.downcase <=> b.title.downcase
        elsif a.date.nil?
          1
        elsif b.date.nil?
          -1
        else
          a.date <=> b.date
        end
      elsif order == "Person"
        a.name.split("_").reverse.join( " ") <=> b.name.split("_").reverse.join( " ")
      else
        a.title.downcase <=> b.title.downcase
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
    html.start_page( get("TITLE"))
    html.breadcrumbs( parents + [self], 'Pictures', false)
    html.start_div( 'payload content')
    index( parents, html, false)
    prepare_source_images( html, true)
    html.end_div
    html.end_page
  end

  def to_html( parents, html)
    html.start_page( get("TITLE"))

    @content.each do |item|
      item.process( self, parents, html)
    end

    dims = @compiler.dimensions( 'icon')
    @images.each_index do |i|
      next if i >= html.floats.size
      prepare_images( @images[i], dims, :prepare_source_image) do |image, w, h, sizes|
        html.add_float( image, w, h, sizes, @images[i][:caption], i)
      end
    end

    if @content.size > 1
      html.end_div
    end
    html.end_div
    html.end_page
  end

  def validate_anchor( lineno, link)
    if ! @compiler.is_anchor_defined?(link)
      error( lineno, "Unknown anchor link: #{link}")
    end
  end
end
