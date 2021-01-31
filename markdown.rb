require 'article_renderer'
require 'utils'

class Markdown
  include Utils

  class ImageInfo
    attr_reader :dims, :mode, :image, :caption
    def initialize( image, caption, mode, dims)
      @image   = image
      @caption = caption
      @mode    = mode
      @dims    = dims
    end
  end

  def initialize( defn)
    @defn            = defn
    @doc             = CommonMarker.render_doc( defn, [:UNSAFE], [:table])
    @html            = []
    @injected        = {}
    @has_only_images = true
  end

  def char_count( snippet)
    count = 0
    snippet.walk do |node|
      if (node.type == :code_block) || (node.type == :text)
        count += node.string_content.size
      end
    end
    count
  end

  def first_image
    return nil if @images.size < 1
    @images.values[0].image
  end

  def has_only_images?
    @has_only_images
  end

  def inject( index, raw)
    @injected[index] = raw
  end

  def part( text)
    doc = CommonMarker.render_doc( text, [:UNSAFE])
    doc.each do |para|
      return para if para.type == :html
      return para.first_child
    end
    raise "Grandchild not found"
  end

  def prepare( compiler, article)
    @images = prepare_images( compiler, article)
    renderer = ArticleRenderer.new( compiler, article, @images)
    @html = renderer.to_html( @doc)
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
        spaced = true
      elsif clump.size > 0
        @has_only_images = false
        if clump.size > 1
          prepare_gallery( compiler, article, images, clump)
        else
          dims = article.get_scaled_dims( compiler.dimensions( spaced ? 'image' : 'icon'), [clump[0][2]])
          prepare_image( article, images, clump[0], spaced ? 'centre' : (even ? 'right' : 'left'), dims)
          even = ! even
        end
        clump, spaced = [], false
      else
        @has_only_images = false
      end
    end

    if clump.size > 0
      prepare_gallery( compiler, article, images, clump)
    end

    images
  end

  def process( article, parents, html)
    html.html( [@html])
  end

  def text_chars
    char_count( @doc)
  end
end