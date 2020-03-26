require 'commonmarker'

class Markdown
  def initialize( defn)
    @doc = CommonMarker.render_doc( defn)
  end

  def part( text)
    doc = CommonMarker.render_doc( text)
    doc.each do |para|
      return para.first_child
    end
    raise "Grandchild not found"
  end

  def prepare( compiler, article)

    # Substitute urls for symbolic names
    @doc.walk do |node|
      if node.type == :link
        mapped = compiler.link( node.url)
        unless mapped || (/^http/ =~ node.url)
          ref, err = compiler.find_article( node.url)
          raise err if err
          mapped = HTML::relative_path( article.sink_filename, ref.sink_filename)
        end

        if mapped
          node.insert_before( part( "[#{node.first_child.string_content}](#{mapped})"))
          node.delete
        end
      end
    end

    # Generate HTML from parse tree
    @html = @doc.to_html.split("\n")

    # Convert tabs to double spaces in the HTML
    @html.each_index do |i|
      @html[i] = @html[i].gsub( "\t") {|match| '  '}
    end

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
    @doc.walk do |node|
      return false if node.type == :code_block
    end
    true
  end
end