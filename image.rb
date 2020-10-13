class Image
  attr_reader :height, :width, :tag

  def initialize( source, sink, tag, width, height)
    @source  = source
    @sink    = sink
    @tag     = tag
    @width   = width
    @height  = height
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

  def prepare_thumbnail( width, height, bw)
    w,h = shave_thumbnail( width, height, @width, @height)
    m = /^(.*)(\.\w*)$/.match( @sink)
    thumbfile = m[1] + "-#{width}-#{height}" + (bw ? '_bw' : '') + m[2]

    if not File.exists?( thumbfile)
      cmd = ["scripts/thumbnail#{bw ? '_bw' : ''}.csh"]
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
end