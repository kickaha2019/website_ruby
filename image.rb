require_relative 'Element'
require 'utils'

class Image < Element
  include Utils
  attr_reader :height, :width, :tag

  def initialize( compiler, article, source)
    @tag = prettify( source.split('/')[-1].split('.')[0])
    @height = @width = 1

    @source = (/^\// =~ source) ? source : abs_filename( article.source_filename, source)
    if ! File.exists?( @source)
      @source, err = compiler.lookup( @source)
      if err
        article.error( "Bad image: #{source}")
        return
      end
    end

    @sink = compiler.sink_filename( @source)
    fileinfo = compiler.fileinfo( @source)
    info = nil
    ts = File.mtime( @source).to_i

    if File.exist?( fileinfo)
      info = IO.readlines( fileinfo).collect {|line| line.chomp.to_i}
      info = nil unless info[0] == ts
    end

    unless info
      dims = get_image_dims( @source)
      info = [ts, dims[:width], dims[:height]]
      File.open( fileinfo, 'w') do |io|
        io.puts info.collect {|i| i.to_s}.join("\n")
      end

      to_delete = []
      sink_dir = File.dirname( compiler.sink_filename( @source))

      if File.directory?( sink_dir)
        Dir.entries( sink_dir).each do |f|
          if m = /^(.*)_\d+_\d+(\..*)$/.match( f)
            to_delete << f if @source.split('/')[-1] == (m[1] + m[2])
          end
        end

        to_delete.each {|f| File.delete( sink_dir + '/' + f)}
      end
    end

    @width  = info[1]
    @height = info[2]
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

  def create_directory( path)
    path = File.dirname( path)
    unless File.exist?( path)
      create_directory( path)
      Dir.mkdir( path)
    end
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

  def page_content?
    true
  end

  def prepare_images( dims, prepare, * args)
    sizes = ''
    (0...dims.size).each do |i|
      sizes = sizes + " size#{i}"
      if ((i+1) >= dims.size) || (dims[i][0] != dims[i+1][0]) || (dims[i][1] != dims[i+1][1])
        file, w, h = send( prepare, * dims[i], * args)
        yield file, w, h, sizes
        sizes = ''
      end
    end
  end

  def prepare_source_image( width, height)
    w,h = constrain_dims( width, height, @width, @height)
    m = /^(.*)(\.\w*)$/.match( @sink)
    imagefile = m[1] + "-#{w}-#{h}" + m[2]

    if not File.exists?( imagefile)
      create_directory( imagefile)

      if w < @width or h < @height
        cmd = ["scripts/scale.csh", @source, imagefile, w.to_s, h.to_s]
        raise "Error scaling [#{file}]" if not system( cmd.join( " "))
      else
        FileUtils.cp( @source, imagefile)
      end
    end

    return imagefile, w, h
  end

  def prepare_thumbnail( width, height)
    w,h = shave_thumbnail( width, height, @width, @height)
    m = /^(.*)(\.\w*)$/.match( @sink)
    unless m
      raise 'Internal error'
    end
    thumbfile = m[1] + "-#{width}-#{height}" + m[2]

    if not File.exists?( thumbfile)
      cmd = ["scripts/thumbnail.csh"]
      cmd << @source
      cmd << thumbfile
      [w,h,width,height].each {|i| cmd << i.to_s}
      raise "Error scaling [#{@source}]" if not system( cmd.join( " "))
    end

    return thumbfile, width, height
  end

  def scaled_height( dim)
    sh = (dim[0] * @height + @width - 1) / @width
    (sh > dim[1]) ? sh : dim[1]
  end

  def set_tag( tag)
    @tag = tag
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

  def to_html( html)
    html.image_centered( self)
  end
end