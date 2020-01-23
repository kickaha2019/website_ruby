File.open( 'index.txt', 'a') do |io|
  io.puts "\nGallery:"

  Dir.entries( '.').each do |f|
    if /\.(jpg|JPG|png)$/ =~ f
      io.puts "  #{f}\n  #{f}\n  "
    end
  end
end