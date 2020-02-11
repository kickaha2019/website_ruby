File.open( 'index.txt', 'a') do |io|
  io.puts "\nGallery:"

  images = []
  Dir.entries( '.').each do |f|
    images << f if /\.(jpg|JPG|png)$/ =~ f
  end

  images.sort.each do |f|
    io.puts "  #{f}\n  #{f}\n  "
  end
end