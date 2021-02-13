class Date < Element
  include Utils
  attr_reader :date

  def initialize( compiler, article, date)
    @date = convert_date( article, date)
  end

  def page_content?
    false
  end

  def to_html( html)
    html.date( @date)
  end
end