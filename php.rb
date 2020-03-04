class PHP
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.php( @entry) do |error|
      article.error( lineno, error)
    end
  end

  def wrap?
    false
  end
end