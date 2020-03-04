class TableEnd
  def process( article, parents, html)
    html.end_table
  end

  def wrap?
    false
  end
end