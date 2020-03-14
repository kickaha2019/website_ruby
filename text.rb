class Text
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.text( parents, @entry) do |error|
      article.error( lineno, error)
    end
  end

  def text_chars
    count = 0
    @entry.each {|item| count += item.size}
    count
  end

  def wrap?
    true
  end
end