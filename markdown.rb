require 'article_renderer'

class Markdown
  def initialize( defn)
    @doc = CommonMarker.render_doc( defn, [:UNSAFE])
    @html = []
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

    # Generate HTML from parse tree
    renderer = ArticleRenderer.new( compiler, article, @injected)
    html = renderer.to_html( @doc)
    @html = html.split("\n")

    # Convert tabs to double spaces in the HTML
    @html.each_index do |i|
      @html[i] = @html[i].gsub( "\t") {|match| '  '}
    end
  end

  def process( article, parents, html)
    html.html( @html)
  end

  def text_chars
    char_count( @doc)
  end

  def wrap?
    @doc.walk do |node|
      return false if node.type == :code_block
    end
    true
  end
end