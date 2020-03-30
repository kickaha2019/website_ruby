require 'yaml'

class ConvertTextToMD
  def initialize

  end

  def Anchor( lines, index, markdown, yaml)
    yaml['anchors'] = [] unless yaml['anchors']
    while /^\s+\S/ =~ lines[index]
      yaml['anchors'] << lines[index]
      index += 1
    end
    index
  end

  def convert( txt_file, md_file, yaml_file)
    raise "#{md_file} exists" if File.exist?( md_file)
    raise "#{yaml_file} exists" if File.exist?( yaml_file)

    markdown = []
    yaml = {}

    begin
      lines = []
      IO.readlines( txt_file).each do |line|
        segs = line.chomp.split( "\r")
        if segs.size > 0
          lines = lines + segs
        else
          lines << ''
        end
      end
      parse( lines, markdown, yaml)
    rescue Exception => bang
      puts "*** #{txt_file}"
      raise
    end

    #raise 'Dev'
    if markdown.size > 0
      puts "... Writing #{md_file}"
      File.open( md_file, 'w') {|io| io.puts markdown.join("\n")}
    end

    if yaml.keys.size > 0
      puts "... Writing #{yaml_file}"
      File.open( yaml_file, 'w') {|io| io.puts yaml.to_yaml}
    end

    puts "... Deleting #{txt_file}"
    File.delete( txt_file)
  end

  def Code( lines, index, markdown, yaml)
    markdown << '~~~'
    while (index < lines.size) && (! (/^\S/ =~ lines[index]))
      line = lines[index]
      index += 1

      if /^\t/ =~ line
        line = line[1..-1]
      elsif /^  / =~ line
        line = line[2..-1]
      else
        line = line[1..-1]
      end

      markdown << line.gsub( "''", '*')
    end
    markdown << '~~~'
    index
  end

  def Date( lines, index, markdown, yaml)
    yaml['date'] = lines[index].strip
    index+1
  end

  def Gallery( lines, index, markdown, yaml)
    Image( lines, index, markdown, yaml)
  end

  def Heading( lines, index, markdown, yaml)
    markdown << "# #{lines[index].strip}"
    index+1
  end

  def HTML( lines, index, markdown, yaml)
    Text( lines, index, markdown, yaml)
  end

  def Icon( lines, index, markdown, yaml)
    yaml['icon'] = lines[index].strip
    index+1
  end

  def Image( lines, index, markdown, yaml)
    yaml['images'] = [] unless yaml['images']
    while /^\s.*\S/ =~ lines[index]
      yaml['images'] << {'path' => lines[index].strip, 'tag' => lines[index+1].strip}
      index += 3
      unless (index > lines.size) || (lines[index-1].strip == '')
        raise "Expected blank line #{index-1}"
      end
    end
    index
  end

  def load_links( path)
    @links = YAML.load( IO.read( path))
  end

  def Link( lines, index, markdown, yaml)
    yaml['links'] = [] unless yaml['links']
    yaml['links'] << {'path' => lines[index].strip, 'tag' => lines[index+1].strip}
    index+2
  end

  def List( lines, index, markdown, yaml)
    markdown << '| | |'
    markdown << '|-|-|'

    while (index < lines.size) && (lines[index].strip != '')
      markdown << lines[index].strip
      index += 1
    end
    index
  end

  def parse( lines, markdown, yaml)
    index = 0
    while index < lines.size
      line = lines[index].chomp
      index += 1

      next if line.strip == ''

      if m = /^(\w*):\s*/.match( line)
        index = send( m[1].to_sym, lines, index, markdown, yaml)
      else
        raise "Unhandled line #{index}"
      end
    end
  end

  def PHP( lines, index, markdown, yaml)
    yaml['extension'] = 'php'
    Text( lines, index, markdown, yaml)
  end

  def process( dir)
    Dir.entries( dir).each do |f|
      next if /^\./ =~ f
      next if 'parameters.txt' == f
      path = dir + '/' + f
      process( path) if File.directory?( path)

      if m = /^(.*)\.txt/.match( path)
        convert( path, m[1] + '.md', m[1] + '.yaml')
      end
    end
  end

  def Table( lines, index, markdown, yaml)
    markdown << lines[index].strip
    markdown << lines[index].split('|').collect {'-'}.join('|')
    index += 1

    while (index < lines.size) && (lines[index].strip != '')
      markdown << lines[index].strip
      index += 1
    end
    index
  end

  def Text( lines, index, markdown, yaml)
    local_links = {}
    while (index < lines.size) && (! (/^\S/ =~ lines[index]))
      line = lines[index].strip.gsub( "''", '*')
      line = line.gsub( /\[[^\[]*\]/) do |link|
        link = link[1...-1]
        if @links[link]
          tag,url = link, @links[link]
        elsif local_links[link]
          tag,url = link, local_links[link]
        elsif m = /^(\S*) (.*)$/.match( link)
          tag,url = m[2], m[1]
          local_links[m[2]] = m[1]
        else
          tag,url = link, link
        end
        "[#{tag}](#{url})"
      end
      markdown << line
      index += 1
    end
    index
  end

  def Title( lines, index, markdown, yaml)
    if lines[index].nil?
      puts "Help"
    end
    yaml['title'] = lines[index].strip
    index+1
  end
end

cnv = ConvertTextToMD.new
cnv.load_links( ARGV[0])
cnv.process( ARGV[1])