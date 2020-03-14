class TableStart
  def initialize( style)
    @style = style
  end

  def process( article, parents, html)
    html.start_table( @style)
  end

  def text_chars
    0
  end

  def wrap?
    false
  end
end