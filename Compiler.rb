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
load "HTML.rb"
load "Link.rb"

class Compiler
  @@default_date = Time.gm( 1970, "Jan", 1)
  attr_reader :title

  # Initialisation
  def initialize( source, sink, debug_pages=nil)
    @errors = 0
    @source = source
    @sink = sink
    @debug_pages = debug_pages.nil? ? nil : Regexp.new( debug_pages)
    @special_chars = {}
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
      if /[\["\|&<>]/ =~ title
        article.error( 0, "Title containing special character: " +	title)
      else
        article.set_title( title)
      end
    end

    if date = defn['date']
      t = convert_date( article, 0, date)
      article.set_date( t)
    end

    if icon = defn['icon']
      if /^\// =~ icon
        article.set_icon( self, 0, icon)
      else
        path = abs_filename( article.source_filename, icon)
        article.set_icon( self, 0, path)
      end
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
        path = image['path'].strip
        unless /^\// =~ path
          path = abs_filename( article.source_filename, path)
        end

        if File.exists?( path)
          article.add_image( self, 0, path, image['tag'])
        else
          article.error( 0, "Image file not found: " + image['path'])
        end
      end
    end

    if links = defn['links']
      links.each do |link|
        article.add_child( Link.new( article, 0, link['path'], link['tag']))
      end
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

  def abs_filename( path, filename)
    return filename if /^\// =~ filename
    path = File.dirname( path)
    while /^\.\.\// =~ filename
      path = File.dirname( path)
      filename = filename[3..-1]
    end
    path + '/' + filename
  end

  def convert_date( article, lineno, text)
    day = -1
    month = -1
    year = -1

    text.split.each do |el|
      i = el.to_i
      if i > 1900
        year = i
      elsif (i > 0) && (i < 32)
        day = i
      else
        if i = ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"].index( el[0..2].downcase)
          month = i + 1
        end
      end
    end

    if (day > 0) && (month > 0) && (year > 0)
      Time.gm( year, month, day)
    else
      article.error( lineno, "Bad date [#{text}]")
      @@default_date
    end
  end

  def error( path, lineno, msg)
    @errors = @errors + 1
    lineref = lineno ? ":#{lineno}" : ""
    puts "***** #{msg} [#{path}#{lineref}]"
  end

  def errors?
    @errors > 0
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

