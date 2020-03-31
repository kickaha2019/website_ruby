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
  attr_reader :title

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

    # Parse all the articles recursively
    @title = load_parameters( "")['TITLE']
    @articles = parse( nil, "")

    # Sync the resource files
    sync_resources( @source + '/resources', @sink + '/resources', /\.(png|css|jpg)$/)

    # Prepare the articles now all articles parsed
    prepare( @articles)

    # Regenerate the HTML files
    regenerate( [], @articles)

    # Delete files not regenerated
    tidy_up( @sink)

    report_errors( @articles)
    puts "*** #{@errors} Errors in compilation" if @errors > 0
  end

  def debug_hook( article)
    if @debug_pages && (@debug_pages =~ article.sink_filename)
      puts "Debugging #{article.title}"
    end
  end

  # Parse the articles
  def parse( parent, path)

    # Skip special directories
    return if ['/resources', '/templates', '/fileinfo'].include?( path)

    source = list_dir( @source + path)

    # Article for the directory
    dir_article = Article.new( @source + path + '/index', @sink + path + '/index.html')
    parent.add_child( dir_article) if parent

    # Hash of articles in this directory
    dir_articles = Hash.new do |h,k|
      a = Article.new( @source + path + '/' + k, @sink + path + '/' + k + '.html')
      dir_article.add_child( a)
      h[k] = a
    end
    dir_articles['index'] = dir_article

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
        parse( dir_article, path1)
      elsif m = /^(.*)\.txt$/.match( file)
        child = dir_articles[m[1]]
        parse_defn( path, file, child)
      elsif m = /^(.*)\.md$/.match( file)
        child = dir_articles[m[1]]
        parse_md( path, file, child)
      elsif m = /^(.*)\.yaml$/.match( file)
        child = dir_articles[m[1]]
        parse_yaml( path, file, child)
      elsif /\.(JPG|jpg|png|zip|rb)$/ =~ file
      else
        raise "Unhandled file: #{path1}"
      end
    end

    dir_article
  end

  def parse_md( path, file, article)
    debug_hook( article)
    article.add_markdown( IO.read( @source + path + "/" + file))
  end

  def parse_yaml( path, file, article)
    debug_hook( article)
    defn = YAML.load( IO.read( @source + path + "/" + file))

    if title = defn['title']
      @commands.Title( self, article, 0, [title])
    end

    if date = defn['date']
      @commands.Date( self, article, 0, [date])
    end

    if icon = defn['icon']
      @commands.Icon( self, article, 0, [icon])
    end

    if ext = defn['extension']
      if ext == 'php'
        article.set_php
      else
        article.error( 0, "Extension #{ext} not supported")
      end
    end

    if images = defn['images']
      images.each do |image|
        @commands.Image( self, article, 0, [image['path'], image['tag']])
      end
    end
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

  def parse_verb( verb, entry, article, lineno)
    lineno += (1 - entry.size)
    while entry.size > 0 and entry[-1] == ""
      entry = entry[0..-2]
    end

    begin
      @commands.send( verb.to_sym, self, article, lineno, entry)
      true
    # rescue NoMethodError => bang
    #   article.error( lineno, 'Unsupported directive: ' + verb)
    #   false
    end
  end

  def prepare( article)
    debug_hook( article)

    begin
      article.prepare( self)
    rescue Exception => bang
      article.error( 0, bang.message)
      raise
    end

    article.children.each do |child|
      prepare( child)
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

#    if article.has_content? || (! article.has_picture_page?)
      html = HTML.new( self, @sink, article.sink_filename)
      html.start
      article.to_html( parents, html)
      html.finish do |error|
        article.error( 0, error)
      end
#    end

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

  def report_errors( article)
    article.report_errors( self)
    article.children.each do |child|
      report_errors( child) if child.is_a?( Article)
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
      if path == @source
        next if file == "README.md"
        next if file == "dimensions.yaml"
        next if file == "links.yaml"
      end
      next if /\.kml\.xml$/ =~ file
      next if /\.(afphoto|command|erb|pdf)$/ =~ file

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

  def load_parameters( path)
    if File.exists?( @source + path + "/parameters.txt")
      params = {}
      IO.readlines( @source + path + "/parameters.txt").each do |line|
        if m = /^(.*)=(.*)$/.match( line.chomp)
          if m[1].strip == 'STYLESHEET' and params[ 'STYLESHEET']
            params[ 'STYLESHEET'] = params[ 'STYLESHEET'] + "\t" + m[2].strip
          else
            params[ m[1].strip] = m[2].strip
          end
        end
      end
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

  def find_article( path)
    if /^\// =~ path
      re = Regexp.new( "^#{@source}#{path}(|/index)$")
    else
      re = Regexp.new( "/#{path}(|/index)$")
    end
    matches = []
    match_article_filename( @articles, re, matches)

    if matches.size < 1
      return nil, "Link not found for #{path}"
    elsif matches.size > 1
      return nil, "Ambiguous link for #{path}"
    else
      return matches[0], nil
    end
  end

  def match_article_filename( article, re, matches)
    matches << article if re =~ article.source_filename
    article.children.each do |child|
      match_article_filename( child, re, matches) if child.is_a?( Article)
    end
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

