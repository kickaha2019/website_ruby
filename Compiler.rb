=begin
	Compiler.rb

	Generate HTML structure from article files
    
    To do:
    
    Cache prepared articles as Ruby code to be eval-ed
    Maintain cache somehow
    For each definition have a Ruby class which knows
    how to add itself to the article
    Article ends up with a lot of verbs which know how
    to render themselves to the HTML
    These verbs are what get serialised to the file
    Check ASCII to be done somewhere
    Content added to be thunk about
=end

require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'
require 'yaml'
require 'cgi'

load "Article.rb"
load "Commands.rb"
load "HTML.rb"
load "Link.rb"

class Compiler

  class Bound
    def initialize( defn)
      @defn = defn
    end

    def get_binding
      binding
    end

    def e( txt)
      CGI::escape( txt)
    end

    def method_missing( symbol, *args)
      if @defn.has_key?(symbol.to_s)
        value = @defn[symbol.to_s]
        return value ? value : ''
      end
      nil
    end
  end

  # Initialisation
  def initialize( source, sink, debug_pages=nil)
    @errors = 0
    @source = source
    @sink = sink
    @debug_pages = debug_pages.nil? ? nil : Regexp.new( debug_pages)
    @special_chars = {}
    @commands = Commands.new
    @templates = {}
    @links = YAML.load( File.open( source + "/links.yaml"))
    @dimensions = YAML.load( File.open( source + "/dimensions.yaml"))
    @generated = {}
    @variables = {}
  end

# =================================================================
# Main logic
# =================================================================

  # Compile
  def compile

    # Load the templates
    load_templates

    # Find anchors in all the articles
    # and also gather lat lons from KML files
    @anchors = Hash.new {|h,k| h[k] = {lat:nil, lon:nil, links:[], used:false}}
    find_anchors('')

    # Parse all the articles recursively
    params = load_parameters( {}, "")
    root_article = parse( nil, "", {})

    # Sync the resource files
    sync_resources( @source + '/resources', @sink + '/resources', /\.(png|css|jpg)$/)

    # Prepare the articles now all articles parsed
    prepare( root_article, root_article)

    # Regenerate the HTML files
    regenerate( [], root_article)

    # Delete files not regenerated
    tidy_up( @sink)

    # Check anchors all used
    @anchors.each_pair do |name, info|
      error( name, nil, "Anchor not used") unless info[:used]
    end

    puts "*** #{@errors} Errors in compilation" if @errors > 0
  end

  def debug_hook( article)
    if @debug_pages && (@debug_pages =~ article.sink_filename)
      puts "Debugging #{article.title}"
    end
  end

  # Find anchors in the articles
  def find_anchors(path)

    # Skip special directories
    return if ['/resources', '/templates', '/fileinfo'].include?( path)

    # Loop over source files
    Dir.entries( @source + path).each do |file|
      next if /^\./ =~ file
      path1 = path + "/" + file

      if File.directory?( @source + path1)
        find_anchors(path1)
      elsif /\.kml\.xml$/ =~ file
        parse_kml_xml( @source + path1)
      elsif m = /^(.*)\.txt$/.match( file)
        found, php, gather, count = [], false, true, 0

        IO.readlines( @source + path1).each do |line|
          php = true if /^PHP/ =~ line
          if /^(Anchor):/ =~ line
            count += 1
            gather = true
          elsif /^\S/ =~ line
            gather = false
          elsif gather && line.strip != ''
            found << line.strip
          end
        end

        url = "#{@source}#{path1.gsub( /\.txt$/, php ? '.php' : '.html')}#a#{count}"
        found.each do |link|
          @anchors[link][:links] << url
        end
      end
    end
  end

  # Parse the articles
  def parse( parent, path, params)

    # Skip special directories
    return if ['/resources', '/templates', '/fileinfo'].include?( path)

    # Do templating for any YAML files
    Dir.entries( @source+path).each do |file|
      path1 = path + "/" + file
      if m = /^(.*)\.yaml$/.match( file)
        if (file != 'links.yaml') && (file != 'dimensions.yaml')
          File.open( @source + path + '/' + m[1] + '.txt', 'w') do |io|
            begin
              defn = YAML.load( IO.read( @source + path1))
              defn['links']   = get_local_links( @source+path)
              defn['anchors'] = @anchors
              erb = ERB.new( @templates[defn['template']])
              io.print erb.result( Bound.new( defn).get_binding)
            rescue
              puts "*** Error templating #{path1}"
              raise
            end
          end
        end
      end
    end

    source = list_dir( @source + path)

    # Load any new parameters
    params = load_parameters( params, path)

    # Generate article for the directory
    source_file = @source + path + "/index.txt"
    sink_file = @sink + path + "/index.html"
    dir_article = Article.new( source_file, sink_file, params, self)
    if File.exist?( source_file)
      parse_defn( path, "index.txt", dir_article)
    end
    parent.add_child( dir_article) if parent

    # Delete any .tmp files in current directory
    source.each do |file|
      if /\.tmp$/ =~ file
        File.delete( @source + path + "/" + file)
      end
    end

    # Loop over source files - skip image files and other specials
    source.each do |file|
      next if ['resources', 'templates', 'fileinfo'].include?( file)

      path1 = path + "/" + file

      if File.directory?( @source + path1)
        Dir.mkdir( @sink + path1) if not File.exists?( @sink + path1)
        parse( dir_article, path1, params)
      elsif m = /^(.*)\.txt$/.match( file)
        if file != 'index.txt'
          child = Article.new( @source + path1, @sink + path + "/#{m[1]}.html", params, self)
          dir_article.add_child( child)
          parse_defn( path, file, child)
        end
      elsif /\.rb$/ =~ file
        text = ['<?php',
                'header("Content-Type: application/force-download");',
                'header("Content-Disposition: attachment; filename=\\"' + file + '\\";")',
                '?>']
        readlines( path, file, self) do |lineno, line|
          text << line
        end
        html = HTML.new( self, @sink, @sink + path + '/' + file + '.php')
        html.start
        html.html( text)
        html.finish do |error|
          error( file, 0, error)
        end
      elsif /\.(JPG|jpg|png|zip)$/ =~ file
      else
        raise "Unhandled file: #{path1}"
      end
    end

    dir_article
  end

  def parse_defn( path, defn, article)
    debug_hook( article)
    verb = nil
    entry = nil
    lineno = readlines( path, defn, article) do |lineno, line|
      if /^\s/ =~ line
        if entry
          entry << line
        else
          article.error( lineno, "Data before directive")
          return
        end
      elsif line.strip == ""
        if entry
          entry << ""
        else
          article.error( lineno, "Data before directive")
          return
        end
      elsif m = /^(.*):$/.match( line)
        if verb
          return if not parse_verb( verb, strip( entry), article, lineno)
        end
        verb = m[1]
        entry = []
      else
        # DEBUG
        #dump = []
        #line.bytes.each { |b| dump << b}
        #p dump
        article.error( lineno, "Syntax error")
        return []
      end
    end

    if verb
      parse_verb( verb, strip(entry), article, lineno)
    end
  end

  def parse_kml_xml( path)
    doc = REXML::Document.new IO.read( path)
    REXML::XPath.each( doc, "//Placemark") do |place|
      entry = @anchors[ place.elements['name'].text.strip]
      coords = place.elements['Point'].elements['coordinates'].text.strip.split(',')
      entry[:lat] = coords[1].to_f
      entry[:lon] = coords[0].to_f
    end
  end

  def parse_verb( verb, entry, article, lineno)
    lineno += (1 - entry.size)
    while entry.size > 0 and entry[-1] == ""
      entry = entry[0..-2]
    end

    begin
      @commands.send( verb.to_sym, article, lineno, entry)
      true
    rescue NoMethodError => bang
      article.error( lineno, 'Unsupported directive: ' + verb)
      false
    end
  end

  def prepare( root_article, article)
    debug_hook( article)
    article.prepare( root_article)
    article.children.each do |child|
      prepare( root_article, child)
    end
  end

  def purify( data, dump)
    File.open( dump, "w") do |f|
      data.force_encoding( 'UTF-8')
      f.write data.encode( 'US-ASCII',
                           :invalid => :replace, :undef => :replace, :universal_newline => true)
    end
  end

  def readlines( path, defn, article)
    lineno = 0
    file = @source + path + "/" + defn
    #puts get_encoding( path, defn)
    #f = File.open( file,
    #			   :mode => "r",
    #              :encoding => get_encoding( path, defn))

    begin
      data = IO.binread( file)
      if not data.ascii_only?
        article.error( lineno, "Not ASCII data")
        purify( data, file+".tmp")
        return lineno
      end

      data.split("\n").each do |line|
        line = line.chomp
        if line.size == 0
          lineno = lineno + 1
          yield lineno, line
        else
          line.split( "\r").each do |subline|
            lineno = lineno + 1
            yield lineno, subline.rstrip.gsub("\t", '  ')
          end
        end
      end
    rescue StandardError => bang
      puts bang.message + "\n" + bang.backtrace.join("\n")
      article.error( lineno, bang.message)
      raise
    end
    lineno
  end

  def regenerate( parents, article)
    debug_hook( article)

    if article.has_content? || (! article.has_picture_page?)
      html = HTML.new( self, @sink, article.sink_filename)
      html.start
      article.to_html( parents, html)
      html.finish do |error|
        article.error( 0, error)
      end
    end

    if article.has_picture_page?
      html = HTML.new( self, @sink, article.picture_sink_filename)
      html.start
      article.to_pictures( parents, html)
      html.finish do |error|
        article.error( 0, error)
      end
    end

    article.children.each do |child|
      regenerate( parents + [article], child) if child.is_a?( Article)
    end
  end

# =================================================================
# Helper methods
# =================================================================

  def begins( text, header)
    return nil if text.size < header.size
    return nil if text[0...header.size] != header
    text[ header.size..-1]
  end

  def error( path, lineno, msg)
    @errors = @errors + 1
    lineref = lineno ? ":#{lineno}" : ""
    puts "***** #{msg} [#{path}#{lineref}]"
  end

  def errors?
    @errors > 0
  end

  def get_local_links( path)
    links = {}
    @anchors.each_pair do |name,entry|
      links[name] = entry[:links].collect {|target| HTML::relative_path( path + '/index.html', target)}
      entry[:urls] = links[name]
    end

    Dir.entries( path).each do |f|
      next if /^\./ =~ f
      next if /^index\./ =~ f
      if m = /^(.*)\.(txt|yaml)$/.match( f)
        links[m[1]] = ["#{m[1]}.html"]
      elsif File.directory?( "#{path}/#{f}")
        links[f] = ["#{f}/index.html"]
      end
    end

    links
  end

  def is_anchor_defined?(name)
    @anchors[name][:used] = true
    ! @anchors[name][:lat].nil?
  end

  def is_source_file?( file)
    file[0..(@source.size)] == (@source + '/')
  end

  def link( ref)
    @links[ref]
  end

  # List files in a directory
  def list_dir( path)
    files = []
    d = Dir.new( path)
    d.each { |file|
      next if /^\./ =~ file
      raise "Error" if file == "." or file == ".."
      next if file == ".DS_Store"
      next if file == "parameters.txt"
      next if file == "structure.txt"
      next if /\.kml\.xml$/ =~ file
      next if /\.(afphoto|command|erb|md|pdf|yaml)$/ =~ file

        #next if file == "index.txt"
      next if /\.timestamp$/ =~ file
      if / / =~ file
        raise "Spaces in name at #{path}/#{file}"
      end
      files.push( file)
    }
    d.close
    files
  end

  def load_parameters( params, path)
    if File.exists?( @source + path + "/parameters.txt")
      params1 = {}
      params.each_pair {|k,v| params1[k] = v}
      IO.readlines( @source + path + "/parameters.txt").each do |line|
        if m = /^(.*)=(.*)$/.match( line.chomp)
          if m[1].strip == 'STYLESHEET' and params1[ 'STYLESHEET']
            params1[ 'STYLESHEET'] = params1[ 'STYLESHEET'] + "\t" + m[2].strip
          else
            params1[ m[1].strip] = m[2].strip
          end
        end
      end
      params = params1
    end
    params
  end

  def load_templates
    Dir.entries( @source + '/templates').each do |f|
      if m = /^(.*)\.(css|html)$/.match( f)
        @templates[m[1]] = IO.readlines( @source + '/templates/' + f).collect {|l| l.chomp}
      end
      if /^(.*)\.erb$/ =~ f
        @templates[f] = IO.read( @source + '/templates/' + f)
      end
    end
  end

  def log( message)
    puts message
  end

  def sink_filename( file)
    if is_source_file?( file)
      return @sink + file[(@source.size)..-1]
    end
    if m = /^(\/resources\/)(.*)$/.match( file)
      return @sink + m[1] + @variables[m[2]]
    end
    file
  end

  def source
    @source
  end

  def strip( lines)
    indent = 100
    lines.each do |line|
      if m = /^(\s*)\S/.match( line)
        li = m[1].size
        indent = li if li < indent
      end
    end
    lines.collect do |line|
      (line.size > indent) ? line[indent..-1] : ''
    end
  end

  def fileinfo( filename)
    @source + '/fileinfo/' + filename.gsub('/','_')
  end

  def dimensions( key)
    @dimensions[key]
  end

  def tidy_up( path)
    keep = false
    Dir.entries( path).each do |f|
      next if /^\./ =~ f
      path1 = path + '/' + f
      if File.directory?( path1)
        if tidy_up( path1)
          keep = true
        else
          puts "... Deleting #{path1}"
          Dir.rmdir( path1)
        end
      else
        if @generated[path1]
          keep = true
        else
          puts "... Deleting #{path1}"
          File.delete( path1)
        end
      end
    end
    keep
  end

  def record( path)
    @generated[path] = true
    path
  end

  def sync_resources( from, to, match)
    Dir.mkdir( from) unless File.exist?( to)
    Dir.entries( from).each do |f|
      next unless match =~ f
      input = from + '/' + f
      f1 = f.split('.')[0] + "_#{File.mtime(input).to_i}." + f.split('.')[1]
      @variables[f] = f1
      output = to + '/' + f1
      record( output)
      unless File.exist?( output)
        FileUtils.cp( input, output)
      end
    end
  end

  def template( name)
    @templates[name]
  end

  def variables
    @variables.each_pair {|k,v| yield k,v}
  end
end

