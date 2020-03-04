class Heading
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.heading( @entry)
  end

  def wrap?
    true
  end
end