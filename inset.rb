require 'image'

class Inset < Image

  def to_html( html)
    html.image_inset( self)
  end
end