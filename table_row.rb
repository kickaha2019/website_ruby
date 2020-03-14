class TableRow
  def initialize( row, width)
    @row = row
    @width = width
  end

  def process( article, parents, html)
    html.start_table_row
    fields = @row.split('|')
    fields.each do |field|
      html.start_table_cell
      html.write( field)
      html.end_table_cell
    end
    (fields.size...@width).each do
      html.start_table_cell
      html.nbsp
      html.end_table_cell
    end
    html.end_table_row
  end

  def text_chars
    @row.size
  end

  def wrap?
    false
  end
end