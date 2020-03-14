class Date
  def initialize( time)
    @time = time
  end

  def process( article, parents, html)
    html.date( @time) do |error|
      article.error( lineno, error)
    end
  end

  def text_chars
    0
  end

  def wrap?
    true
  end
end