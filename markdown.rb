require 'commonmarker'

class Markdown
  def initialize( defn)
    @doc = CommonMarker.render_doc( defn, [:UNSAFE])
    @html = []
    @floated = {}
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

  def get_max_floats
    max_floats = 0
    floats do |float|
      max_floats += 1
    end
    max_floats
  end

  def floats
    chars_seen = 301
    @doc.each do |child|
      if child.type == :paragraph && (chars_seen > 300)
        yield child
      end
      chars_seen += char_count( child)
    end
  end

  def inject_float( index, raw)
    n_floats = 0
    floats do |node|
      if n_floats == index
        key = "FLOATED#{index}DETAOLF"
        @floated[key] = raw
        node.first_child.insert_before( part( key))
      end
      n_floats += 1
    end
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
    html = @doc.to_html
    @html = @doc.to_html.split("\n")

    # Convert tabs to double spaces in the HTML
    @html.each_index do |i|
      @html[i] = @html[i].gsub( "\t") {|match| '  '}
    end

    # Inject raw float HTML
    @html.each_index do |i|
      @html[i] = @html[i].gsub( /FLOATED\d+DETAOLF/) do |match|
        @floated[match]
      end
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
    char_count( @doc)
  end

  def wrap?
    @doc.walk do |node|
      return false if node.type == :code_block
    end
    true
  end
end