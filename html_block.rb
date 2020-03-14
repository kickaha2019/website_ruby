class HTMLBlock
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.html( @entry) do |error|
      article.error( lineno, error)
    end
  end

  def text_chars
    10000
  end

  def wrap?
    false
  end
end