class TableStart
  def process( article, parents, html)
    html.start_table( article.get( "TABLE_CLASS"))
  end

  def wrap?
    false
  end
end