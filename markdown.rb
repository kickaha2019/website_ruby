require 'utils'

class Markdown < Element
  include Utils

  def initialize( compiler, article, lines)
    @lines = lines
  end

  def process( article, parents, html)
    html.html( [@html])
  end

  def to_html( html)
    html.markdownify( @lines.join( "\n"))
  end
end