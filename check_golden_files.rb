#
# Check generated files against golden files
#
# Command line arguments:
#   Golden file directory
#   Generated file directory
#   File for commands to refresh golden files
#

def load_filtered( path)
  lines = IO.readlines( path)
  lines.select! do |line|
    ! (/var marker = L\.marker/ =~ line)
  end
  lines.select! do |line|
    ! (/marker\.bindPopup/ =~ line)
  end
  lines.select! do |line|
    ! (/^<link rel/ =~ line)
  end
  lines.select! do |line|
    ! (/^resources\/logo_/ =~ line)
  end
  lines.join( "\n")
end

def check_golden_files( dir, io)
  errors = 0

  Dir.entries( ARGV[0] + dir).each do |f|
    next if /^\./ =~ f
    golden    = ARGV[0] + dir + '/' + f
    generated = ARGV[1] + dir + '/' + f

    if File.directory?( golden)
      errors += check_golden_files( dir + '/' + f, io)
    elsif /\.html$/ =~ f
      io.puts "cp #{generated} #{golden}"
      # puts "... Checking #{golden}"
      if File.exist?( generated)
        if load_filtered( golden) != load_filtered( generated)
          errors += 1
          puts "*** #{generated} doesn't match #{golden}"
          puts "    diff #{generated} #{golden}"
        end
      else
        errors += 1
        puts "*** #{generated} not found"
      end
    end
  end

  errors
end

errors = 0
File.open( ARGV[2], 'w') do |io|
  io.puts '#!/bin.csh'
  errors += check_golden_files( '', io)
end

exit(1) if errors > 0
