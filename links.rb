class Links < Element
  def initialize( compiler, article, lines)
    lines.each do |line|
      if m = /^(\S+)\s+(.*)$/.match( line)
        article.add_child( Link.new( article, m[1], m[2]))
      else
        article.error( 'Bad links')
      end
    end
  end

  def prepare( compiler, article, parents)
    article.children do |child|
      child.prepare( compiler, parents)
    end
  end
end