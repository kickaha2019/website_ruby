require 'commonmarker'
require 'utils'

class ArticleRenderer < CommonMarker::HtmlRenderer
  include Utils

  def initialize( compiler, article, injected)
    super()
    @compiler = compiler
    @article  = article
    @injected = injected
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

  def link(node)
    if node.url.nil?
      url = ''
    elsif /^(http|https|mailto):/ =~ node.url
      url = node.url
    elsif /\.(html|php)$/ =~ node.url
      url = relative_path( @article.sink_filename, node.url)
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
      inject = @injected[@top_para] ? @injected[@top_para] : ''
      if @do_para
        out( '<p>', inject, :children, '</p>')
      else
        out( inject, :children)
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