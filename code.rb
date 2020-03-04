class Code
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.code( @entry) do |error|
      article.error( lineno, error)
    end
  end

  def wrap?
    false
  end
end