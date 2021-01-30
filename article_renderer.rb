require 'commonmarker'
require 'utils'

class ArticleRenderer < CommonMarker::HtmlRenderer
  include Utils

  def initialize( compiler, article, images)
    super()
    @compiler = compiler
    @article  = article
    @images   = images
    @do_para  = false
  end

  def has_text?( node)
    node.walk do |child|
      return true if child.type == :text
    end
    false
  end

  def html(node)
    out( node.string_content)
  end

  def image(node)
    if @images[node.url]
      send( ("image_" + @images[node.url][0]).to_sym, node, @images[node.url][1])
    else
      @article.error( "Unprocessed image #{node.url}")
    end
  end

  def image_centre( node, image)
    image_out( node, image,'image', 'centre', :prepare_source_image)
  end

  def image_end_gallery( node, image)
    image_inside_gallery( node, image)
    out( '</DIV CLASS>')
  end

  def image_float( node, image, side)
    image_out( node, image, 'icon', side, :prepare_thumbnail)
  end

  def image_inside_gallery( node, image)
    out( '<DIV>')
    image_out( node, image, 'icon', '', :prepare_thumbnail)
    out( node.title, '</DIV>')
  end

  def image_left( node, image)
    image_float( node, image, 'left')
  end

  def image_out( node, image, size, side, prepare)
    raw   = ["<A CLASS=\"#{side}\" HREF=\"\">"]
    dims  = @article.get_scaled_dims( @compiler.dimensions( size), [image])

    image.prepare_images( dims, prepare) do |image, w, h, sizes|
      @compiler.record( image)
      rp = relative_path( @article.sink_filename, image)
      raw << "<IMG CLASS=\"#{sizes}\" SRC=\"#{rp}\" WIDTH=\"#{w}\" HEIGHT=\"#{h}\" ALT=\"#{prettify(@article.title)} picture\">"
    end

    raw << '</A>'
    out( raw.join(''))
  end

  def image_right( node, image)
    image_float( node, image, 'right')
  end

  def image_start_gallery( node, image)
    out( '<DIV CLASS="gallery t1">')
    image_inside_gallery( node, image)
  end

  def link(node)
    if node.url.nil?
      url = ''
    elsif /^(http|https|mailto):/ =~ node.url
      url = node.url
    elsif /\.(html|php)$/ =~ node.url
      url = relative_path( @article.sink_filename, node.url)
    elsif /\.(jpeg|jpg|png|gif)$/i =~ node.url
      @article.error( "Link to image: #{node.url}")
      url = ''
    else
      url = @compiler.link( node.url)
      unless url
        ref, err = @compiler.lookup( node.url)
        if err
          url = ''
          @article.error( err)
        else
          url = relative_path( @article.sink_filename, ref.sink_filename)
        end
      end
    end

    out( "<a href=\"#{escape_href( url)}\">", :children, '</a>')
  end

  def paragraph( node)
    if node.parent.type == :document
      if @do_para
        out( '<p>', :children, '</p>')
      else
        out( :children)
        @do_para = true
      end
      @top_para += 1
    else
      super
    end
  end

  def table(node)
    @do_para = false if node.parent.type == :document
    clazz = has_text?( node.first_child) ? 'table' : 'list'
    out( "<div class=\"#{clazz}\">")
    super
    out( '</div>')
  end

  def to_html( doc)
    @top_para = 0
    output = render( doc)
    warnings.each do |w|
      @article.error( w)
    end
    @article.error( 'Markdown unknown issue') if output.nil? || (output.strip == '')

    output
  end
end