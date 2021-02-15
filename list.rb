class List < Element
  include Utils

  def initialize( compiler, article, lines)
    @list = {}
    lines.each do |line|
      if m = /^(\S+)\s+(.*)$/.match( line)
        @list[m[1]] = m[2]
      else
        article.error( 'Bad list')
      end
    end
  end

  # def prepare( compiler, article, parents)
  #   @list.keys.each do |k|
  #     @list[k] = setup_links_in_text( compiler, article, @list[k])
  #   end
  # end

  def to_html( html)
    html.list( @list)
  end
end