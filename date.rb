class Date
  def initialize( time)
    @time = time
  end

  def process( article, parents, html)
    if article.has_any_content?
      html.date( @time) do |error|
        article.error( lineno, error)
      end
    end
  end

  def text_chars
    0
  end

  def wrap?
    true
  end
end