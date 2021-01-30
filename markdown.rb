require 'article_renderer'
require 'utils'

class Markdown
  include Utils

  def initialize( defn)
    @defn     = defn
    @doc      = CommonMarker.render_doc( defn, [:UNSAFE], [:table])
    @html     = []
    @injected = {}
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
    @images.values[0][1]
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
    prepare_image( compiler, article, images, clump[0], 'start_gallery')
    clump[1..-2].each {|image| prepare_image( compiler, article, images, image, 'inside_gallery')}
    prepare_image( compiler, article, images, clump[-1], 'end_gallery')
  end

  def prepare_image( compiler, article, images, info, mode)
    if images[info[0]]
      article.error( "Duplicate image #{url}")
    else
      path  = article.abs_filename( article.source_filename, info[0])
      image = article.describe_image( compiler, path, nil)
      images[info[0]] = [mode, image, info[1]]
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
        clump << [m[2], html]
      elsif line == ''
        spaced = true
      elsif clump.size > 0
        if clump.size > 1
          prepare_gallery( compiler, article, images, clump)
        else
          prepare_image( compiler, article, images, clump[0], spaced ? 'centre' : (even ? 'right' : 'left'))
          even = ! even
        end
        clump, spaced = [], false
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