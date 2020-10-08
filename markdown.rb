require 'article_renderer'
require 'utils'

class Markdown
  include Utils

  def initialize( defn)
    @doc      = CommonMarker.render_doc( defn, [:UNSAFE], [:table])
    @html     = []
    @rotates  = []
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

  def get_float_points
    points = []
    chars_seen = 301
    paras = 0
    @doc.each do |child|
      if child.type == :paragraph
        if chars_seen > 300
          points << paras
        end
        paras += 1
      end
      chars_seen += char_count( child)
    end
    points
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
    renderer = ArticleRenderer.new( compiler, article, @injected)
    @html = renderer.to_html( @doc)
  end

  def prepare_float( compiler, article, images, points, pi)
    raw = ["<A CLASS=\"#{((pi % 2) == 1) ? 'left' : 'right'}\" HREF=\"#{article.picture_rp}\">"]
    size_rotates = {}
    dims = article.get_scaled_dims( compiler.dimensions( 'icon'), images)
    id = ''

    images.each_index do |index|
      images[index].prepare_images( dims, :prepare_thumbnail, nil) do |image, w, h, sizes|
        compiler.record( image)
        rp = relative_path( article.sink_filename, image)
        if images.size > 1
          if size_rotates[sizes].nil?
            size_rotates[sizes] = @rotates.size
            @rotates << []
          end
          @rotates[size_rotates[sizes]] << rp
          id = " ID=\"image#{size_rotates[sizes]}\""
        end
        if index == 0
          raw << "<IMG #{id} CLASS=\"#{sizes}\" SRC=\"#{rp}\" ALT=\"#{images[index].tag}\">"
        end
      end
    end

    raw << '</A>'
    inject( points[pi], raw.join(''))
  end

  def prepare_floats( compiler, article)
    points = get_float_points

    if article.images.size <= points.size
      article.images.each_index do |index|
        prepare_float( compiler, article, [article.images[index]], points, index)
      end
    else
      per_float = (article.images.size / points.size).to_i
      from      = 0

      points.each_index do |index|
        to = from + per_float
        to = to + 1 if (article.images.size - to) > per_float * (points.size - index)
        prepare_float( compiler, article, article.images[from...to], points, index)
        from = to
      end
    end
  end

  def process( article, parents, html)
    if @rotates.size > 0
      script = ['<SCRIPT>']
      @rotates.each_index do |i|
        script << "var index#{i} = 0;"
        images = ["var images#{i} = "]
        separ  = '['
        @rotates[i].each do |image|
          images << separ
          images << "\"#{image}\""
          separ = ','
        end
        images << '];'
        script << images.join('')
      end
      script << "function change_images() {"
      @rotates.each_index do |i|
        script << "  index#{i} = index#{i} + 1;"
        script << "  if (index#{i} >= images#{i}.length) {index#{i} = 0;}"
        script << "  document.getElementById(\"image#{i}\").src=images#{i}[index#{i}];"
      end
      script << "}"
      script << "setInterval( change_images, 3000);"
      script << "</SCRIPT>"

      html.script( script.join("\n"))
    end

    html.html( [@html])
  end

  def text_chars
    char_count( @doc)
  end

  def wrap?
    @doc.walk do |node|
      return false if node.type == :code_block
      return false if node.type == :html
      return false if node.type == :table
    end
    true
  end
end