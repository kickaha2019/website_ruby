require 'article_renderer'
require 'utils'

class Markdown < Element
  include Utils

  def initialize( compiler, article, lines)
    @lines = lines
#    @doc         = CommonMarker.render_doc( @defn, [:UNSAFE], [:table])
    @html        = []
    @injected    = {}
    @has_gallery = false
  end

  def prepare( compiler, article, parents)
    @lines.each_index do |i|
      @lines[i] = setup_links_in_text( compiler, article, @lines[i])
    end
  end

  def prepare_gallery( compiler, article, images, clump)
    dims = article.get_scaled_dims( compiler.dimensions( 'icon'), clump.collect {|c| c[2]})
    prepare_image( article, images, clump[0], 'start_gallery', dims)
    clump[1..-2].each {|image| prepare_image( article, images, image, 'inside_gallery', dims)}
    prepare_image( article, images, clump[-1], 'end_gallery', dims)
  end

  def prepare_image( article, images, info, mode, dims)
    if images[info[0]]
      article.error( "Duplicate image #{url}")
    else
      images[info[0]] = ImageInfo.new( info[2], info[1], mode, dims)
    end
  end

  def prepare_images( compiler, article)
    images = {}
    clump   = []
    spaced  = false
    even    = true

    @defn.split( "\n").each do |line|
      line = line.strip

      if m = /^!\[(.*)\]\((.*)\)(.*)$/.match( line)
        if m[3] != ''
          article.error( "Bad image declaration for #{m[2]}")
        end
        html = CommonMarker.render_html( m[1], :DEFAULT)
        if m1 = /^<p>(.*)<\/p>$/i.match( html)
          html = m1[1]
        end
        path  = article.abs_filename( article.source_filename, m[2])
        image = article.describe_image( compiler, path, nil)
        clump << [m[2], html, image]
      elsif line == ''
        spaced = (clump.size > 0)
      elsif clump.size > 0
        if clump.size > 1
          prepare_gallery( compiler, article, images, clump)
        else
          dims = article.get_scaled_dims( compiler.dimensions( spaced ? 'image' : 'icon'), [clump[0][2]])
          prepare_image( article, images, clump[0], spaced ? 'centre' : (even ? 'right' : 'left'), dims)
          even = ! even
        end
        clump, spaced = [], false
      end
    end

    if clump.size > 0
      @has_gallery = true
      prepare_gallery( compiler, article, images, clump)
    end

    images
  end

  def process( article, parents, html)
    html.html( [@html])
  end

  def to_html( html)
    html.markdownify( @lines.join( "\n"))
  end
end