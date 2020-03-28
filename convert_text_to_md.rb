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

    if markdown.size > 0
      puts "... Would have written #{md_file}"
      # File.open( md_file, 'w') {io.puts markdown.join("\n")}
    end

    if yaml.keys.size > 0
      puts "... Would have written #{yaml_file}"
      # File.open( yaml_file, 'w') {io.puts yaml.to_yaml}
    end

    puts "... Would have deleted #{txt_file}"
    # File.delete( txt_file)
  end

  def Code( lines, index, markdown, yaml)
    markdown << '~~~'
    index = Text( lines, index, markdown, yaml)
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

  def Link( lines, index, markdown, yaml)
    yaml['links'] = [] unless yaml['links']
    yaml['links'] << {'path' => lines[index].strip, 'tag' => lines[index+1].strip}
    index+2
  end

  def List( lines, index, markdown, yaml)
    markdown << '| | |'
    markdown << '|-|-|'

    while (index < lines.size) && (lines[index].strip != '')
      markdown << lines[index].chomp
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
    markdown << lines[index]
    markdown << lines[index].split('|').collect {'-'}.join('|')
    index += 1

    while (index < lines.size) && (lines[index].strip != '')
      markdown << lines[index].chomp
      index += 1
    end
    index
  end

  def Text( lines, index, markdown, yaml)
    while (index < lines.size) && (! (/^\S/ =~ lines[index]))
      markdown << lines[index].chomp.gsub( "''", '*')
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
cnv.process( ARGV[0])