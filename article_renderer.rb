require 'commonmarker'

class ArticleRenderer < CommonMarker::HtmlRenderer
  def initialize( compiler, article, injected)
    super()
    @compiler = compiler
    @article  = article
    @injected = injected
  end

  def link(node)
    if node.url.nil?
      url = ''
    elsif /^http/ =~ node.url
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
    out( '<div class="table">')
    super
    out( '</div>')
  end

  def to_html( doc)
    @top_para = 0
    output = render( doc)
    warnings.each do |w|
      @article.error( 0, w)
    end
    output
  end
end