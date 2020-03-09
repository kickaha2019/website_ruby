class TableStart
  def initialize( style)
    @style = style
  end

  def process( article, parents, html)
    html.start_table( @style)
  end

  def wrap?
    false
  end
end