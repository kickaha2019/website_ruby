require 'commonmarker'

class Markdown
  def initialize( defn)
    @defn = defn
  end

  def prepare( compiler)
    
    # Substitute urls for symbolic names
    defn = @defn.gsub( /\]\([^\)]*\)/) do |match|
      if mapped = compiler.link( match[2..-2])
        "](#{mapped})"
      else
        match
      end
    end

    doc = CommonMarker.render_doc( defn)
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