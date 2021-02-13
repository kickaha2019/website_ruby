class Blurb < Element
  attr_reader :blurb

  def initialize( compiler, article, blurb)
    @blurb = blurb
  end

  def page_content?
    false
  end
end