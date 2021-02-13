class Title < Element
  attr_reader :title

  def initialize( compiler, article, title)
    @title = title
  end

  def page_content?
    false
  end
end