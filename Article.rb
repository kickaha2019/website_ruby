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
  attr_accessor :content_added, :blurb

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
    @metadata        = {'date' => nil, 'gallery' => nil}
    @errors          = []
    @markdown        = []
    @no_index        = false
    @time            = nil

    els = source.split('/')
    els = els[0..-2] if els[-1] == 'index'
    set_title( els[-1])
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

  def add_markdown( defn)
    @markdown = defn.split( "\n")
  end

  def check_for_bad_characters
    @markdown.each do |line|
      ok = true
      line.bytes { |b| ok = false if b > 127}
      if not ok
        error( "Non-ASCII characters in markdown: #{line}")
        return
      end
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
    @metadata['date']
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
        if image
          height = image.scaled_height( dim)
          min_height = height if height < min_height
        end
      end

      scaled_dims << [dim[0], min_height]
    end

    scaled_dims
  end

  def has_any_content?
    @markdown.join('').strip != ''
  end

  def has_gallery?
    @metadata['gallery']
  end

  def icon
    return @icon if @icon

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
    check_for_bad_characters

    if @metadata['icon']
      err = nil

      if /^\// =~ @metadata['icon']
        path = compiler.source + @metadata['icon']
      else
        path = abs_filename( @source_filename, @metadata['icon'])
        if ! File.exists?( path)
          path, err = compiler.lookup( @metadata['icon'])
        end
      end

      if err.nil? && File.exists?( path)
        @icon = describe_image( compiler, path, nil)
      else
        error( err ? err : "Icon #{@icon} not found")
        @icon = nil
      end
    else
      @markdown.each do |line|
        if m = /^!\[.*\]\((.*)\)/.match( line)
          @icon = describe_image( compiler, abs_filename( source_filename, m[1]), nil) unless @icon
          break
        end
      end
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

  def set_date_and_time( d, t)
    if @metadata['date'].nil?
      @metadata['date'] = d
      @time = t
    end
  end

  def set_icon( path)
    @metadata['icon'] = path
  end

  def set_no_index
    @no_index = true
  end

  # def set_php
  #   return if /\.php$/ =~ @sink_filename
  #   if m = /^(.*)\.html$/.match( @sink_filename)
  #     @sink_filename = m[1] + '.php'
  #   else
  #     error( 'Unable to set page to PHP')
  #   end
  # end

  def set_title( title)
    @metadata['title'] = title
  end

  def setup_breadcrumbs( parents)
    @metadata['breadcrumbs'] = parents.collect do |parent|
      {'title' => prettify( parent.title),
       'path'  => relative_path( @sink_filename, parent.sink_filename)}
    end
    @metadata['breadcrumbs'] << {'title' => prettify(title), 'path' => false}
  end

  def setup_gallery( compiler)
    gallery = []
    start   = 1000000

    @markdown.each_index do |i|
      if /^!\[/ =~ @markdown[i]
        start = i unless start < i
        gallery << @markdown[i]
      elsif @markdown[i].strip != ''
        start, gallery = 1000000, []
      end
    end

    if gallery.size > 0
      @markdown = @markdown[0...start]
      gallery = gallery.collect do |line|
        if m = /^!\[(.*)\]\((.*)\)/.match( line.strip)
          path = abs_filename( source_filename, m[2])
          [CommonMarker.render_html( m[1], :DEFAULT), describe_image( compiler, path, nil)]
        else
          error( "Bad image definition: " + line)
          nil
        end
      end.select {|entry| entry}

      icon_dims = get_scaled_dims( compiler.dimensions( 'icon'), gallery.collect {|c| c[1]})
      @metadata['gallery'] = gallery.collect do |rec|
        entry = {'title' => rec[0]}
        entry['icons'] = setup_image( compiler, rec[1], icon_dims, :prepare_thumbnail, '', true)
        entry
      end
    end
  end

  def setup_image( compiler, image_desc, dims, prepare, side='', wrap=false)
    return nil unless image_desc
    recs = []

    image_desc.prepare_images( dims, prepare) do |image, w, h, sizes|
      compiler.record( image)
      rp = relative_path( sink_filename, image)

      inject = []
      if wrap
        wrap_dims = get_scaled_dims( compiler.dimensions( 'image'), [image_desc])
        inject << ' onclick="javascript: showOverlay('
        sized_images = []
        image_desc.prepare_images( wrap_dims, :prepare_source_image) do |image, w, h, sizes|
          compiler.record( image)
          sizes.split(' ').each do |size|
            sized_images[size[-1..-1].to_i] = image
          end
        end

        separ = ''
        sized_images[1..-1].each do |image|
          inject << "#{separ}'#{image}'"
          separ = ','
        end

        inject << ');"'
      end
      recs << "<IMG CLASS=\"#{sizes} #{side}\" SRC=\"#{rp}\" WIDTH=\"#{w}\" HEIGHT=\"#{h}\" ALT=\"#{prettify(title)} picture\"#{inject.join('')}>"
    end

    recs.join('')
  end

  def setup_images( compiler)
    even = true
    @markdown.each_index do |i|
      if m = /^!\[(.*)\]\((.*)\)/.match( @markdown[i].strip)
        path  = abs_filename( source_filename, m[2])
        desc  = describe_image( compiler, path, nil)
        inset = ((i+1) < @markdown.size) && (@markdown[i+1].strip != '')
        dims  = get_scaled_dims( compiler.dimensions( inset ? 'icon' : 'image'), [desc])

        side = inset ? (even ? 'right' : 'left') : 'centre'
        @markdown[i] = setup_image( compiler, desc, dims, inset ? :prepare_thumbnail : :prepare_source_image, side, inset)
        even = ! even if inset
      end
    end
  end

  def setup_index( compiler, parents)
    if @children.size > 0
      to_index = children
    else
      to_index = siblings( parents) # .select {|a| a != self}
    end

    #backstop = BackstopIcon.new( compiler.sink_filename( "/resources/down_cyan.png"))
    index_dims = get_scaled_dims( compiler.dimensions( 'icon'), to_index.collect {|r| r.icon})

    @metadata['index'] = to_index.collect do |relative|
      {'title'    => prettify(relative.title),
       'tooltip'  => relative.blurb,
       'path'     => relative_path( sink_filename, relative.sink_filename),
       'icon'     => setup_image( compiler, relative.icon, index_dims, :prepare_thumbnail),
       'selected' => (self == relative)}
    end
  end

  def setup_layout
    return if @metadata['layout']

    @metadata['layout'] = 'image_index'
    @metadata['index'].each do |entry|
      @metadata['layout'] = 'index' unless entry['icon']
    end

    if @no_index ||
        (@metadata['index'].size == 0) ||
        ((@children.size == 0) && @metadata['gallery'])
      @metadata['layout'] = 'noindex'
    end

    if has_any_content?
      @metadata['layout'] += '_content'
    end
  end

  def setup_link( compiler, link)
    if /^(http|https|mailto):/ =~ link
      link
    elsif /\.(html|php)$/ =~ link
      relative_path( sink_filename, link)
    elsif /\.(jpeg|jpg|png|gif)$/i =~ link
      error( "Link to image: #{link}")
      ''
    else
      url = compiler.link( link)
      unless url
        ref, err = compiler.lookup( link)
        if err
          error( err)
          url = ''
        else
          url = relative_path( sink_filename, ref.sink_filename)
        end
      end
      url
    end
  end

  def setup_links( compiler)
    @markdown.each_index do |i|
      @markdown[i] = setup_links_in_text( compiler, @markdown[i]) unless /^\s*!\[/ =~ @markdown[i]
    end
  end

  def setup_links_in_text( compiler, text)
    if m = /^(.*)\[([^\]]*)\]\(([^\)]*)\)(.*)$/.match( text)
      setup_links_in_text( compiler, m[1]) + "[#{m[2]}](" + setup_link( compiler, m[3]) + ')' + setup_links_in_text( compiler, m[4])
    else
      text
    end
  end

  def setup_root_path( root_dir)
    @metadata['root'] = relative_path( File.dirname(@source_filename), root_dir)
  end

  def siblings( parents)
    return [] if parents.size == 0
    parents[-1].children
  end

  def sink_filename
    if @metadata['permalink']
      els = @sink_filename.split('/')
      els[-1] = @metadata['permalink']
      els.join('/')
    else
      @sink_filename
    end
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
      elsif a1.time
        if a2.time
          a1.time <=> a2.time
        else
          -1
        end
      elsif a2.time
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

  def time
    return @time if @time

    children.each do |child|
      if t = child.time
        return t
      end
    end

    nil
  end

  def title
    @metadata['title']
  end

  def to_html( parents, html)
    html.start_page( parents[0] ? parents[0].title : @title)
    html.breadcrumbs( parents, title, false) if parents.size > 0
    html.start_div( 'payload content')

    index( parents, html)

    if has_any_content?
      html.start_div( 'story t1')
    end

    if has_any_content? && date
      html.date( date) do |err|
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

  def to_jekyll
    lines = [@metadata.to_yaml]
    lines << '---'
    lines += @markdown
    lines.join( "\n")
  end
end
