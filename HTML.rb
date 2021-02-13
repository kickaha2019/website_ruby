require 'erb'
require 'yaml'
require 'utils'

class HTML
  include Utils
  attr_reader :floats

  def initialize( compiler, sink, path)
    @compiler     = compiler
    @path         = @compiler.record( path)
    @output       = []
    @css          = []
    @error        = nil
    @sink         = sink
    @local_links  = {}
    @inset_even   = true
  end

  def add_blurb( blurb)
    @output << '<SPAN CLASS="tooltiptext">'
    write( blurb)
    @output << '</SPAN>'
  end

  def add_caption( article, caption)
    @output << '<DIV>'
    caption.process( article, [], self)
    @output << '</DIV>'
  end

  def add_index_dummy
    start_div 'index dummy size1 size2 size3'
    end_div
  end

  def begin_index( target, inject_class='')
    @output << "<A CLASS=\"index t0 tooltip\" HREF=\"#{relative_path( @path, target)}\">" if target
    start_div( "index t0 #{inject_class}") unless target
  end

  def breadcrumbs( parents, title, pictures_link)
    start_div( 'breadcrumbs t0 content')
    parents.each do |parent|
      rp = relative_path( @path, parent.sink_filename)
      @output << "<A HREF=\"#{rp}\">#{prettify( parent.title)}</A> &raquo; "
    end
    @output << '<SPAN>' + check( prettify(title)) + '</SPAN>'
    if pictures_link
      @output << " &raquo; <A HREF=\"#{picture_rp}\">Pictures</A>"
    end
    @output << "</DIV>"
  end

  def check( text)
    ok = true
    text.bytes { |b| ok = false if b > 127}
    if not ok
      yield "Non-ASCII characters in [#{text}]"
    end
    text
  end

  def children( parent, articles)
    articles.each do |article|
      if parent == article
        start_div( 'index_text t0')
        @output << "<span> &raquo; #{prettify( article.title)}</span>"
        @output << "</DIV>"
      else
        start_div( 'index_text t0')
        rp = relative_path( @path, article.sink_filename)
        @output << " &raquo; <A HREF=\"#{rp}\">#{prettify( article.title)}</A>"
        @output << "</DIV>"
      end
    end
  end

  def date( time)
    start_div( 'date')
    @output << format_date( time) + "</DIV>"
  end

  def dimensions( key)
    @compiler.dimensions( key)
  end

  def encode_special_chars( text)
    text = text.gsub( '&', '&amp;').gsub( '<', '&lt;').gsub( '>', '&gt;')
    text.gsub( /&amp;(\w+|#\d+);/) do |m|
      '&' + m[5..-1]
    end
  end

  def end_cell
    @output << "</div>"
  end

  def end_div
    @output << "</div>"
  end

  def end_index( target, alt_text)
    start_div
    @output << '<span>' unless target
    write( alt_text)
    @output << '</span>' unless target
    end_div
    end_div unless target
    @output << "</A>" if target
  end

  def end_indexes
    @output << "</div>"
  end

  def end_page
    @compiler.template('footer').each do |line|
      @output << line
    end
  end

  def finish

    # Embed CSS into the HTML lines
    to_write = []
    @output.each do |line|
      to_write << line
      if /^<style>/ =~ line
        @css.each {|css| to_write << css}
      end
    end

    Dir.mkdir( File.dirname( @path)) if not File.exists?( File.dirname( @path))
    rewrite = ! File.exists?( @path)

    if ! rewrite
      current = IO.readlines( @path).collect {|line| line.chomp}
      rewrite = (current.join("\n").strip != to_write.join("\n").strip)
    end

    if rewrite
      puts "... Writing #{@path}"
      File.open( @path, "w") do |f|
        f.puts to_write.join( "\n")
      end
    end

    if @error
      yield @error
    end
  end

  def gallery( images)
    start_div( 'gallery t1')
    icon_dims = get_scaled_dims( @compiler.dimensions( 'icon'), images)
    images.each do |image|
      start_div
      start_div
      image_wrapped( image, 'centre', icon_dims)
      end_div
      start_div
      markdownify( image.tag)
      end_div
      end_div
    end
    (0..7).each {@output << '<DIV CLASS="dummy size1 size2 size3"></DIV>'}
    end_div
  end

  def html( lines)
    lines.each do |line|
      @output << line
    end
  end

  def image( image, side, dims, prepare, inject='')
    image.prepare_images( dims, prepare) do |image_file, w, h, sizes|
      if image_file.nil?
        raise 'Internal error'
      end
      @compiler.record( image_file)
      rp = relative_path( @path, image_file)
      @output << "<IMG CLASS=\"#{sizes} #{side}\" SRC=\"#{rp}\" WIDTH=\"#{w}\" HEIGHT=\"#{h}\" ALT=\"#{prettify(image.tag)} picture\"#{inject}>"
    end
  end

  def image_centered( image)
    image( image,
          'centre',
           get_scaled_dims( @compiler.dimensions( 'image'), [image]),
          :prepare_source_image)
  end

  def image_inset( image)
    image_wrapped( image,
                   @inset_even ? 'right' : 'left',
                   get_scaled_dims( @compiler.dimensions( 'icon'), [image]))
    @inset_even = ! @inset_even
  end

  def image_wrapped( image, side, icon_dims)
    inject = [' onclick="javascript: showOverlay(']
    sized_images = []

    image_dims = get_scaled_dims( @compiler.dimensions( 'image'), [image])
    image.prepare_images( image_dims, :prepare_source_image) do |image_file, w, h, sizes|
      @compiler.record( image_file)
      sizes.split(' ').each do |size|
        sized_images[size[-1..-1].to_i] = image_file
      end
    end

    separ = ''
    sized_images[1..-1].each do |image_file|
      inject << "#{separ}'#{image_file}'"
      separ = ','
    end

    inject << ');"'
    image( image, side, icon_dims,:prepare_thumbnail, inject.join(''))
  end

  def list( entries)
    @output << '<table class="list">'
    entries.each_pair do |k,v|
      @output << "<tr><th>#{k}</th><td>"
      markdownify( v)
      @output << '</td></tr>'
    end
    @output << '</table>'
  end

  def markdownify( md)
    @output << CommonMarker.render_html( md, :DEFAULT)
  end

  def no_indexes
    @compiler.template('no_indexes').each do |line|
      write_css( line)
    end
  end

  def picture_rp
    m = /^(.*)\./.match( @path.split('/')[-1])
    m[1] + '_pictures.html'
  end

  def script( script)
    @output.each_index do |i|
      if @output[i] == '<script></script>'
        @output[i] = script
        return
      end
    end
    raise "Unable to find where to inject script into HTML"
  end

  def sink_filename( path)
    @compiler.sink_filename( path)
  end

  def small_no_indexes
    @compiler.template('small_no_indexes').each do |line|
      write_css( line)
    end
  end

  def start
  end

  def start_cell
    start_div( 'cell')
  end

  def start_div( css_class=nil)
    embed_class = css_class ? " class=\"#{css_class}\"" : ''
    @output << "<div#{embed_class}>"
  end

  def start_index( index_classes)
    start_div( "index #{index_classes}")
  end

  def start_indexes
    start_div( "indexes t0")
  end

  def start_page( title)
    rp = relative_path( @path, @sink)
    @compiler.template('header').each do |line|
      @compiler.variables do |k,v|
        line = line.gsub( "$#{k}$", v)
      end
      @output << line.gsub( '$TITLE$', title).gsub( '$SITE$', rp)
    end
  end

  def write( line)
    line = encode_special_chars( line)
    @output << check( line)
  end

  def write_css( line)
    @css << line
  end
end

