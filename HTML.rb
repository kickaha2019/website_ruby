require 'erb'
require 'yaml'

class HTML
  attr_reader :floats
  @@links = {}

  def initialize( sink, path, links, templates)
    @path         = path
    @output       = []
    @css          = []
    @error        = nil
    @float_height = 10
    @floats       = []
    @sink         = sink
    @templates    = templates
    @n_anchors    = 0
    @max_floats   = 0

    if @@links.size == 0
      links.each_pair do |k,v|
        @@links[k] = v
      end
    end
  end

  def add_float( img, w, h, classes, caption, float)
    rp = relative_path( @path, img)
    @output[@floats[float]] += "\n<IMG CLASS=\"#{classes}\" WIDTH=\"#{w}\" HEIGHT=\"#{h}\" SRC=\"#{rp}\" ALT=\"#{caption}\">"
  end

  def add_caption( caption)
    @output << '<DIV>'
    write( caption)
    @output << '</DIV>'
  end

  def add_index( img, w, h, sizes, target, alt_text)
    @output << "<A CLASS=\"index t0 #{sizes}\" HREF=\"#{relative_path( @path, target)}\">"
    start_div
    image( img, w, h, alt_text)
    end_div
    start_div
    write( alt_text)
    end_div
    @output << "</A>"
  end

  def add_index_dummy
    start_div 'index dummy size1 size2 size3'
    end_div
  end

  def add_index_title( text)
    start_cell
    start_div 'title'
    write( text)
    end_div
    end_cell
  end

  def anchor
    @n_anchors += 1
    @output << "<a name=\"#{@n_anchors}\"></a>"
  end

  def breadcrumbs( parents, title, pictures_link)
    @output << "<DIV CLASS=\"breadcrumbs t0 content\">"
    parents.each do |parent|
      rp = relative_path( @path, parent.sink_filename)
      @output << "<A HREF=\"#{rp}\">#{HTML.prettify( parent.title)}</A> &raquo; "
    end
    @output << '<SPAN>' + check( HTML.prettify(title)) + '</SPAN>'
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

  def children( articles)
    articles.each do |article|
      @output << "<DIV CLASS=\"index_text t0\">"
      rp = relative_path( @path, article.sink_filename)
      @output << " &raquo; <A HREF=\"#{rp}\">#{HTML.prettify( article.title)}</A>"
      @output << "</DIV>"
    end
  end

  def code( lines)
    sep = "<DIV CLASS=\"code\">"
    lines.each do |line|
      @output << (sep + encode_special_chars( line).gsub( " ", "&nbsp;"))
      sep = "<BR>"
    end
    @output << "</div>"
  end

  def date( time)
    @output << "<DIV CLASS=\"date\">" + format_date( time) + "</DIV>"
  end

  def disable_float( float)
    write_css( ".f#{float} {display: none}")
  end

  def dump
    p [@path, @output.size]
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

  def end_gallery
    @output << "</div>"
  end

  def end_grid
    @output << "</div>"
  end

  def end_index
    @output << "</div>"
  end

  def end_indexes
    @output << "</div>"
  end

  def end_page
    @templates['footer'].each do |line|
      @output << line
    end
  end

  def end_table
    @output << "</table></div>"
  end

  def end_table_cell
    @output << "</TD>"
  end

  def end_table_row
    @output << "</TR>"
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

  def format_date( date)
    ord = if (date.day > 3) and (date.day < 21)
        "th"
    elsif (date.day % 10) == 1
        "st"
    elsif (date.day % 10) == 2
        "nd"
    elsif (date.day % 10) == 3
        "rd"
    else
        "th"
    end
    date.strftime( "%A, ") + date.day.to_s + ord + date.strftime( " %B %Y")
  end

  def heading( text)
    @output << '<div class="heading">'
    write( text)
    @output << '</div>'
  end

  def html( lines)
    lines.each do |line|
      @output << line
    end
  end

  def image( file, w, h, alt_text, inject='')
    alt_text = 'TTBA' unless alt_text
    rp = relative_path( @path, file)
    @output << "<IMG CLASS=\"#{inject}\" SRC=\"#{rp}\" WIDTH=\"#{w}\" HEIGHT=\"#{h}\" ALT=\"#{alt_text}\">"
  end

  def insert_float
    return if @floats.size >= @max_floats
    @floats << @output.size
    @output << "<A CLASS=\"#{((@floats.size % 2) == 0) ? 'left' : 'right'}\" HREF=\"#{picture_rp}\">"
    @output << '</A>'
  end

  def link( defn)
    if @@links[defn]
      defn = @@links[defn] + ' ' + defn
    end

    defn = defn.split(' ')
    if defn.size < 2
      @error = "Bad link: #{defn}"
      return ''
    end

    ref, text = defn[0], defn[1..-1].join(' ')
    @@links[text] = ref

    if /^http/ =~ ref
      target = (/maps\.apple\.com/ =~ ref) ? '' : 'TARGET="_blank" '
      "<A HREF=\"#{ref}\" #{target}REL=\"nofollow\">#{check(text)}</A>"
    elsif /^\// =~ ref
      rp = relative_path( @path, ref)
      if rp
        "<A HREF=\"#{rp}\">#{check(text)}</A>"
      else
        @error = "Bad link: #{ref} #{defn}"
        ''
      end
    else
      "<A HREF=\"#{ref}\">#{check(text)}</A>"
    end
  end

  def nbsp
    @output << '&nbsp;'
  end

  def php( lines)
    @output << "<?php"
    lines.each do |line|
      @output << line
    end
    @output << "?>"
  end

  def picture_rp
    m = /^(.*)\./.match( @path.split('/')[-1])
    m[1] + '_pictures.html'
  end

  def self.prettify( name)
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

  def relative_path( from, to)
    HTML::relative_path( from, to)
  end

  def self.relative_path( from, to)
    from = from.split( "/")
    from = from[0...-1] if /\.(html|php|txt)$/ =~ from[-1]
    to = to.split( "/")
    while (to.size > 0) and (from.size > 0) and (to[0] == from[0])
      from = from[1..-1]
      to = to[1..-1]
    end
    rp = ((from.collect { ".."}) + to).join( "/")
    (rp == '') ? '.' : rp
  end

  def set_max_floats( n)
    @max_floats = n
  end

  def start
  end

  def start_code
    @output << "<div class=\"code\">"
  end

  def start_cell
    @output << "<div class=\"cell\">"
  end

  def start_div( css_class=nil)
    if css_class.nil?
      @output << '<div>'
    else
      @output << "<div class=\"#{css_class}\">"
    end
  end

  def start_gallery
    @output << "<div class=\"gallery\">"
  end

  def start_grid
    @output << "<div class=\"grid\">"
  end

  def start_index( index_classes)
    @output << "<div class=\"index #{index_classes}\">"
  end

  def start_indexes
    @output << "<div class=\"indexes t0\">"
  end

  def start_page( title)
    rp = relative_path( @path, @sink)
    @templates['header'].each do |line|
      @output << line.gsub( '$TITLE$', title).gsub( '$SITE$', rp)
    end
  end

  def start_table( css_class)
    @output << "<DIV CLASS=\"table\"><TABLE CLASS=\"#{css_class}\">"
  end

  def start_table_cell
    @output << "<TD>"
  end

  def start_table_row
    @output << "<TR>"
  end

  def text( parents, lines)
    written, float = 0, true
    @output << "<DIV CLASS=\"text\">"

    lines.each do |line|
      if line.strip == ''
        @output << '<BR><BR>'
        written += 50
        if written > 300
          written, float = 0, true
        end
      else
        insert_float if float
        float = false
        write( line)
        written += line.size
      end
    end
    @output << "</DIV>"
  end

  def write( line)
    line = encode_special_chars( line)
    while m = /^([^\[]*)\[([^\]]*)\](.*)$/.match( line)
      line = m[1] + link( m[2]) + m[3]
    end
    while m = /^([^']*)''([^']*)''(.*)$/.match( line)
      line = m[1] + "<B>" + m[2] + "</B>" + m[3]
    end
    @output << check( line)
#		@output << check(text)
  end

  def write_css( line)
    @css << line
  end
end

