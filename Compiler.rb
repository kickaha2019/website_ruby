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
require 'utils'

class Compiler
  include Utils
  @@default_date = Time.gm( 1970, "Jan", 1)

  # Initialisation
  def initialize( cache, source, sink, debug_pages=nil)
    @cache         = cache
    @errors        = 0
    @source        = source
    @sink          = sink
    @debug_pages   = debug_pages.nil? ? nil : Regexp.new( debug_pages)
    @special_chars = {}
    @templates     = {}
    @links         = YAML.load( File.open( source + "/links.yaml"))
    @dimensions    = YAML.load( File.open( source + "/dimensions.yaml"))
    @generated     = {}
    @variables     = {}
    @key2paths     = Hash.new {|h,k| h[k] = []}
  end

# =================================================================
# Main logic
# =================================================================

  # Compile
  def compile

    # Load the templates
    # load_templates

    # Parse all the articles recursively
    @articles = parse( nil, "")

    # Sync the resource files
    config = YAML.load( IO.read( @source + '/_config.yml'))
    sync_resources( config, @source + '/resources', @sink + '/resources', /\.(png|css|jpg)$/)
    File.open( @sink + '/_config.yml', 'w') {|io| io.puts config.to_yaml}

    # Prepare the articles now all articles parsed
    prepare( [], @articles)

    # Regenerate the Jekyll files
    regenerate( [], @articles)

    # Delete files not regenerated
    tidy_up( @sink)

    report_errors( @articles)
    puts "*** #{@errors} Errors in compilation" if @errors > 0
  end

  def debug_hook( article)
    # puts "DEBUG100: #{article.sink_filename}"
    if @debug_pages && (@debug_pages =~ article.sink_filename)
      puts "Debugging #{article.title}"
    end
  end

  # Parse the articles
  def parse( parent, path)

    # Article for the directory
    dir_article = Article.new( @source + path + '/index', @sink + path + '/index.html')
    remember( path, dir_article)
    parent.add_child( dir_article) if parent

    # Hash of articles in this directory
    dir_articles = Hash.new do |h,k|
      a = Article.new( @source + path + '/' + k, @sink + path + '/' + k + '.html')
      dir_article.add_child( a)
      remember( path + '/' + k, a)
      h[k] = a
    end
    dir_articles['index'] = dir_article

    # Loop over source files - skip image files and other specials
    Dir.entries( @source + path).each do |file|
      next if /^\./ =~ file
      next if /^_/ =~ file
      next if (path == '') && ['resources', 'templates', 'README.md','dimensions.yaml','links.yaml'].include?( file)
      path1 = path + "/" + file

      if File.directory?( @source + path1)
        Dir.mkdir( @sink + path1) if not File.exists?( @sink + path1)
        parse( dir_article, path1)
      elsif m = /^(.*)\.md$/.match( file)
        child = dir_articles[m[1]]
        parse_md( path, file, child)
      # elsif m = /^(.*)\.yaml$/.match( file)
      #   child = dir_articles[m[1]]
      #   parse_yaml( path, file, child)
      elsif /\.(JPG|jpg|JPEG|jpeg|png|zip|rb|kml|afphoto|command|erb|pdf)$/ =~ file
        remember( path1, @source + path1)
      else
        raise "Unhandled file: #{path1}"
      end
    end

    dir_article
  end

  def parse_md( path, file, article)
    debug_hook( article)
    text = IO.read( @source + path + "/" + file)
    lines = text.split( "\n")

    if /^---/ =~ lines[0]
      end_yaml = 1
      while ! (/^---/ =~ lines[end_yaml])
        end_yaml += 1
      end

      if /---/ =~ lines[end_yaml+1]
        article.error( 'Duplicated front matter')
      end

      parse_yaml( lines[0..end_yaml-1].join("\n"), article)
      text = lines[end_yaml+1..-1].join("\n")
    end

    article.add_markdown( text) if text.strip != ''
  end

  def parse_yaml( defn, article)
    debug_hook( article)
    defn = YAML.load( defn)

    defn.each_pair do |k,v|
      case k

      when 'blurb'
        article.set_blurb( v)

      when 'date'
        t = convert_date( article, v)
        article.set_date_and_time( format_date(t), t)

      when 'extension'
        article.set_metadata( k,v)
        article.set_metadata( 'permalink', article.sink_filename[(@sink.size+1)..-1])

      when 'icon'
        article.set_icon( v)

      when 'links'
        v.each do |link|
          article.add_child( Link.new( article, link['path'], link['tag']))
        end

      when 'no_index'
        article.set_no_index

      when 'title'
        if /[\["\|&<>]/ =~ v
          article.error( 0, "Title containing special character: " +	v)
        else
          article.set_title( v)
        end

      else
        article.set_metadata( k,v)
      end
    end
  end

  def dimensions( key)
    @dimensions[key]
  end

  def error( path, msg)
    @errors = @errors + 1
    puts "***** #{msg} [#{path}]"
  end

  def errors?
    @errors > 0
  end

  def fileinfo( filename)
    @cache + '/fileinfo/' + filename.gsub('/','_')
  end

  def link( ref)
    @links[ref]
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

  def lookup( path)
    matches = @key2paths[path]

    if matches.size < 1
      return nil, "Path not found for #{path}"
    elsif matches.size > 1
      return nil, "Ambiguous path for #{path}"
    else
      return matches[0], nil
    end
  end

  def prepare( parents, article)
    debug_hook( article)

    begin
      article.prepare( self, parents)
    rescue Exception => bang
      article.error( bang.message)
      raise
    end

    article.children.each do |child|
      prepare( parents + [article], child)
    end
  end

  def regenerate( parents, article)
    debug_hook( article)
    sink_filename = article.sink_filename.gsub( '.html', '.md').gsub( '.php', '.md')
    record( sink_filename)

    article.setup_root_path( @source)
    article.setup_breadcrumbs( parents)
    article.setup_gallery( self)
    article.setup_index( self, parents)
    article.setup_images( self)
    article.setup_links( self)
    article.setup_layout
    new_src = article.to_jekyll

    if (! File.exist?( sink_filename)) || (new_src.strip != IO.read( sink_filename).strip)
      File.open( sink_filename, 'w') {|io| io.puts new_src}
    end

    article.children.each do |child|
      regenerate( parents + [article], child) if child.is_a?( Article)
    end
  end

  def remember( key, path)
    key = key.split('/')
    (0...key.length).each do |i|
      @key2paths[ key[i..-1].join('/')] << path
    end
  end

  def report_errors( article)
    article.report_errors( self)
    article.children.each do |child|
      report_errors( child) if child.is_a?( Article)
    end
  end

  def sink_filename( file)
    if file[0..(@source.size)] == (@source + '/')
      return @sink + file[(@source.size)..-1]
    end
    if m = /^(\/resources\/)(.*)$/.match( file)
      return @sink + m[1] + m[2]
    end
    file
  end

  def tidy_up( path)
    keep = false
    Dir.entries( path).each do |f|
      next if /^\./ =~ f
      next if /^_/ =~ f
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

  def source
    @source
  end

  def sync_resources( config, from, to, match)
    Dir.mkdir( to) unless File.exist?( to)
    Dir.entries( from).each do |f|
      next unless match =~ f
      input = from + '/' + f
      output = to + '/' + f

      if /\.(css|js)$/ =~ f
        f1 = f.split('.')[0] + "_#{File.mtime(input).to_i}." + f.split('.')[1]
        config[f.gsub('.','_')] = f1
        output = to + '/' + f1
      end

      record( output)
      FileUtils.cp( input, output)
    end
  end

  def template( name)
    @templates[name]
  end

  def variables
    @variables.each_pair {|k,v| yield k,v}
  end
end

