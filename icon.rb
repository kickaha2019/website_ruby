require 'image'

class Icon < Image
  def page_content?
    false
  end

  def to_html( html)
  end
end