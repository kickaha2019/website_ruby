class PHP < Element
  def initialize( compiler, article, lines)
    @lines = lines
  end

  def to_html( html)
    html.html( @lines)
  end
end