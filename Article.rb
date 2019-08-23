=begin
  Article.rb

  Represent article for HTML generation
=end

require 'fileutils'

class Article
    attr_accessor :parent, :content_added

  def initialize( source, sink, params, compiler)
    @source_filename = source
    @sink_filename = sink
    @params = params
    @compiler = compiler
    @seen_links = {}
    @content = []
    @children = []
    @children_sorted = false
    @parent = nil
    @float = nil
    @icon = nil
    @php = false

    add_content do |html|
      index( html, 0)
      if (children.size == 0) && index_images?
        html.heading( prettify( title))
      end
    end

    sels = source.split( /[\/\.]/)
    set_title( ((sels[-2] != 'index') ? sels[-2] : sels[-3]))
  end

  def add_child( article)
    @children << article
    @children_sorted = false
    article.parent = self
  end

  def add_content( &block)
    @content << block
  end

  def add_image( float, lineno, &block)
    if float
      @float = block
    else
      add_content( &block)
    end
  end

  # def add_image( entry, param, lineno)
  # 	if entry.size < 1 or entry.size > 2
  # 		error( lineno, "Bad image declaration")
  # 		return
  # 	end
  #
  # 	alt_text = entry[1] ? entry[1] : (@title ? prettify(@title) : get( "TITLE"))
  # 	HTMLImage.new( self, lineno, source_filename(entry[0]), alt_text, param)
  # 	#HTMLImage.new( self, lineno, source_filename(entry[0]), alt_text, param)
  # end
  #
  # def add_left_right( entry, side, lineno)
  # 	if ensure_no_float( lineno) and (html = add_image( entry, "FLOAT", lineno))
  # 		@float = HTMLPageFloat.new( self, lineno, html, side)
  # 	end
  # end

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
      @children = @compiler.sort( @children, get( "ORDER"))
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

  def date
    if @date.nil?
      return children[0].date if children?
    end
    @date # ? @date : Time.gm( 1970, "Jan", 1)
  end

  def ensure_no_float( lineno=nil)
    if @float
      error( lineno, "Left and right must be paired up with text blocks")
      false
    else
      true
    end
  end

  def error( lineno, msg)
    @compiler.error( @source_filename, lineno, msg)
  end

  def find_content( type)
      @content.each_index do |i|
          return i if @content[i].is_a?( type)
      end
      nil
  end

  def float
    @float, f = nil, @float
    f
  end

  def get( name)
    raise "Parameter [#{name}] not set" if @params[name].nil?
    @params[ name]
  end

  def get_image_caption( image_filename)
    @compiler.get_image_caption( image_filename)
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

  def has_text?
    @has_text
  end

  def icon
    if @icon.nil? && index_images?
      children.each do |child|
        if icon = child.icon
          return icon
        end
      end
    end

    @icon
  end

  def index( html, lineno)
    if index_images?
      index_using_images( html, lineno)
    else
      ancestors, ancestor = [], parent
      while ! ancestor.nil?
        ancestors << [ancestor.sink_filename, prettify( ancestor.title)]
        ancestor = ancestor.parent
      end
      html.breadcrumbs( ancestors.reverse, prettify( title))

      if index_children?
        html.children( children.collect {|child| [child.sink_filename, prettify( child.title)]})
      end
    end
  end

  def index_children?
    get( 'INDEX_CHILDREN').downcase != 'false'
  end

  def index_images?
    get( 'INDEX') == 'image'
  end

  def index_image_dimensions
    [get( 'INDEX_WIDTH').to_i, get( 'INDEX_HEIGHT').to_i]
  end

  def index_resource( lineno, html, dir, page, image = nil)
    if image.nil?
      image = @compiler.sink( "/resources/#{dir}_cyan.png")
    else
      image = prepare_thumbnail( lineno, image, * index_image_dimensions)
    end

    html.add_index( image,
            * index_image_dimensions,
            page.sink_filename,
            prettify( page.title))
  end

  def index_using_images( html, lineno)
    html.start_index

    if not parent.nil?
      home = parent
      while not home.parent.nil?
        home = home.parent
      end

      index_resource( lineno, html, 'home', home)
      if parent != home
        index_resource( lineno, html, 'up', parent)
      end
    end

    if n = neighbour(-1)
      index_resource( lineno, html, 'left', n)
    end

    if n = neighbour(1)
      index_resource( lineno, html, 'right', n)
    end

    if (@children.size > 0) && (not parent.nil?)
      html.add_index_title( prettify( title))
    end

    if index_children?
      children.each do |child|
        index_resource( lineno, html, 'down', child, child.icon)
      end
    end

    (0..5).each {html.add_index_dummy}

    html.end_index
  end

  def is_source_file?( file)
    @compiler.is_source_file?( file)
    #File.exists?( source_filename( file))
  end

  def match_article_filename( re)
    @compiler.match_article_filename( re)
  end

  def name
    if m = /(^|\/)([^\/]*)\.txt/.match( @source_filename)
      m[2]
    else
      @source_filename.split( "/")[-1]
    end
  end

  def neighbour( dir)
    neighbours = siblings.select {|a| a.has_content?}
    index = -2

    neighbours.each_index do |i|
      index = i if neighbours[i] == self
    end

    index += dir
    return nil if (index < 0) || (index >= neighbours.size)
    neighbours[index]
  end

  def next_gallery_index
    @galleries += 1
  end

  def php?
    @php
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

  def prepare_sink_image( lineno, file, tw, th)
    key, info = @compiler.get_cache( file) do |filename|
      get_image_dims( lineno, filename)
    end
    return "" if not info

    constrain_dims( tw, th, info[:width], info[:height])
    #[info[:width], info[:height]]
    #"<IMG #{inject}SRC=\"#{rp}\" WIDTH=\"#{w}\" HEIGHT=\"#{h}\" ALT=\"#{alt_text}\">"
  end

  def prepare_source_image( lineno, file)
    key, info = @compiler.get_cache( file) do |filename|
      get_image_dims( lineno, filename)
    end

    return nil if not info

    w,h = constrain_dims( get("IMAGE_MAX_WIDTH").to_i, get("IMAGE_MAX_HEIGHT").to_i,
                          info[:width], info[:height])
    if info[:sink_filename]   != @compiler.sink_filename( file)         or
        not File.exists?( info[:sink_filename])                         or
        info[:sink_timestamp] != File.mtime( info[:sink_filename]).to_i or
        info[:sink_width]     != w                                      or
        info[:sink_height]    != h

      #p [file, info]
      #raise "Re-scaling"
      #if File.exists?( info[:sink_filename])
      #	p info # DEBUG CODE
      #	p [sink_filename( file), File.mtime( info[:sink_filename]), w, h]
      #	raise file # DEBUG CODE
      #else
      #	puts "***** Missing " + info[:sink_filename]
      #end

      if w < info[:width] or h < info[:height]
        cmd = ["scripts/scale.csh"]
        cmd << file
        cmd << @compiler.sink_filename( file)
        cmd << w.to_s
        cmd << h.to_s
        raise "Error scaling [#{file}]" if not system( cmd.join( " "))
      else
        FileUtils.cp( file, @compiler.sink_filename( file))
      end

      info[:sink_filename]  = @compiler.sink_filename( file)
      info[:sink_timestamp] = File.mtime( info[:sink_filename]).to_i
        info[:sink_width]     = w
        info[:sink_height]    = h
      @compiler.append_cache( key, info)
    end

    info[:sink_filename]
  end

  def prepare_thumbnail( lineno, file, width, height)
    key, info = @compiler.get_cache( file, "-#{width}-#{height}") do |filename|
      get_image_dims( lineno, filename)
    end

    return nil if not info

    w,h = shave_thumbnail( width, height, info[:width], info[:height])
    thumbfile = file[0..-5] + "-#{width}-#{height}" + file[-4..-1]

    if info[:sink_filename]   != @compiler.sink_filename( thumbfile)    or
        not File.exists?( info[:sink_filename])                         or
        info[:sink_timestamp] != File.mtime( info[:sink_filename]).to_i

      info[:sink_filename]  = @compiler.sink_filename( thumbfile)
      cmd = ["scripts/thumbnail.csh"]
      cmd << file
      cmd << info[:sink_filename]
      [w,h,width,height].each {|i| cmd << i.to_s}
      raise "Error scaling [#{file}]" if not system( cmd.join( " "))

      info[:sink_timestamp] = File.mtime( info[:sink_filename]).to_i
      @compiler.append_cache( key, info)
    end

    info[:sink_filename]
  end

  def prettify( name)
    if m = /^\d+[:_](.+)$/.match( name)
      name = m[1]
    end
    if name.downcase == name
      name.split( "_").collect do |part|
         part.capitalize
      end.join( " ")
    else
      name.gsub( "_", " ")
    end
  end

  def root_source_filename( file)
    @compiler.root_source_filename( file)
  end

  def set_date( t)
    @date = t if @date.nil?
  end

  def set_icon( path)
    if @icon.nil?
      if not File.exists?( path)
        error( 0, "Icon #{path} not found")
      else
        @icon = path
      end
    end
  end

  def set_image_caption( lineno, image_filename, caption)
    caption = caption.join( " ")
    if /[\.\["\|<>]/ =~ caption
      error( lineno, "Image caption containing special character: " + caption)
    else
      @compiler.set_image_caption( image_filename, caption)
    end
  end

  def set_php
    @php = true
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

  def siblings
    return [] if @parent.nil?
    @parent.children
  end

  def sink_filename
    @sink_filename.sub( ".txt", php? ? ".php" : ".html")
  end

  def source_filename
    @source_filename
  end

  def title
    @title ? @title : "Home"
  end

  def to_html( html)
    ensure_no_float
    html.start_page( get("TITLE"))
    html.start_body
    html.start_content
    @content.each do |item|
      if item.is_a?( Array)
        item[0].call( [html, item[1]])
      else
        item.call( html)
      end
    end
    html.end_content
    html.end_body
    html.end_page
  end

  def to_xml_date( time)
    @compiler.to_xml_date( time)
  end
end
