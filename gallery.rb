class Gallery < Element
  def initialize( compiler, article, lines)
    @images = []
    lines.each do |line|
      if m = /^(\S+)\s+(.*)$/.match( line)
        @images << Image.new( compiler, article, m[1])
        @images[-1].set_tag( m[2])
      else
        article.error( 'Bad gallery')
      end
    end
  end

  def first_image
    @images[0]
  end

  def to_html( html)
    html.gallery( @images)
  end
end