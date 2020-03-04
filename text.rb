class Text
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.text( parents, @entry) do |error|
      article.error( lineno, error)
    end
  end

  def wrap?
    true
  end
end