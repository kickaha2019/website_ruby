class TableEnd
  def process( article, parents, html)
    html.end_table
  end

  def text_chars
    0
  end

  def wrap?
    false
  end
end