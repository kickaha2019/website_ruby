require 'commonmarker'

class Markdown
  def initialize( defn)
    @defn = defn
  end

  def part( text)
    doc = CommonMarker.render_doc( text)
    doc.each do |para|
      return para.first_child
    end
    raise "Grandchild not found"
  end

  def prepare( compiler)
    doc = CommonMarker.render_doc( @defn)

    # Substitute urls for symbolic names
    doc.walk do |node|
      if node.type == :link
        if mapped = compiler.link( node.url)
          node.insert_before( part( "[#{node.first_child.string_content}](#{mapped})"))
          node.delete
        end
      end
    end

    @html = doc.to_html.split("\n")

    # Avoid blank line at top by flattening first paragraph
    nested = 0
    @html.each_index do |i|
      line = @html[i]
      if nested == 0
        if m = /^<p>(.*)$/.match( line)
          @html[i] = m[1]
          nested = 1
        else
          break
        end
      elsif m = /^<p>(.*)$/.match( line)
        nested += 1
      elsif m = /^(.*)<\/p>$/.match( line)
        nested -= 1
        if nested <= 0
          @html[i] = m[1]
          break
        end
      end
    end
  end

  def process( article, parents, html)
    html.html( @html)
  end

  def text_chars
    @html.size
  end

  def wrap?
    false
  end
end