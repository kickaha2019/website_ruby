class NoIndex < Element
  attr_reader :flag

  def initialize( compiler, article, value)
    @flag = (/true/i =~ value)
  end

  def page_content?
    false
  end
end