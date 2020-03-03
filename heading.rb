class Heading
  def initialize( entry)
    @entry = entry
  end

  def process( article, parents, html)
    html.heading( @entry)
  end
end