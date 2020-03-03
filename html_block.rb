class HTMLBlock
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.html( @entry) do |error|
      article.error( lineno, error)
    end
  end
end