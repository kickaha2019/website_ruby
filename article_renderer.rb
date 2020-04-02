require 'commonmarker'

class ArticleRenderer < CommonMarker::HtmlRenderer
  def initialize( compiler, article, injected)
    super()
    @compiler = compiler
    @article  = article
    @injected = injected
  end

  def has_text?( node)
    node.walk do |child|
      return true if child.type == :text
    end
    false
  end

  def link(node)
    if node.url.nil?
      url = ''
    elsif /^(http|https|mailto):/ =~ node.url
      url = node.url
    elsif /\.(html|php)$/ =~ node.url
      url = HTML::relative_path( @article.sink_filename, node.url)
    else
      url = @compiler.link( node.url)
      unless url
        ref, err = @compiler.find_article( node.url)
        if err
          url = ''
          @article.error( 0, err)
        else
          url = HTML::relative_path( @article.sink_filename, ref.sink_filename)
        end
      end
    end

    out( "<a href=\"#{escape_href( url)}\">", :children, '</a>')
  end

  def paragraph( node)
    if node.parent.type == :document
      inject = @injected[@top_para] ? @injected[@top_para] : ''
      if @top_para == 0
        out( inject, :children)
      else
        out( '<p>', inject, :children, '</p>')
      end
      @top_para += 1
    else
      super
    end
  end

  def table(node)
    clazz = has_text?( node.first_child) ? 'table' : 'list'
    out( "<div class=\"#{clazz}\">")
    super
    out( '</div>')
  end

  def to_html( doc)
    @top_para = 0
    output = render( doc)
    warnings.each do |w|
      @article.error( 0, w)
    end
    @article.error( 0, 'Markdown unknown issue') if output.nil? || (output.strip == '')
    output
  end
end