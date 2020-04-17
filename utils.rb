module Utils
  def abs_filename( path, filename)
    return filename if /^\// =~ filename
    path = File.dirname( path)
    while /^\.\.\// =~ filename
      path = File.dirname( path)
      filename = filename[3..-1]
    end
    path + '/' + filename
  end

  def convert_date( article, text)
    day = -1
    month = -1
    year = -1

    text.split.each do |el|
      i = el.to_i
      if i > 1900
        year = i
      elsif (i > 0) && (i < 32)
        day = i
      else
        if i = ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"].index( el[0..2].downcase)
          month = i + 1
        end
      end
    end

    if (day > 0) && (month > 0) && (year > 0)
      Time.gm( year, month, day)
    else
      article.error( "Bad date [#{text}]")
      @@default_date
    end
  end

  def format_date( date)
    ord = if (date.day > 3) and (date.day < 21)
            "th"
          elsif (date.day % 10) == 1
            "st"
          elsif (date.day % 10) == 2
            "nd"
          elsif (date.day % 10) == 3
            "rd"
          else
            "th"
          end
    date.strftime( "%A, ") + date.day.to_s + ord + date.strftime( " %B %Y")
  end

  def prettify( name)
    if m = /^\d+[:_](.+)$/.match( name)
      name = m[1]
    end
    if name.downcase == name
      name.split( "_").collect do |part|
        part.capitalize
      end.join( " ")
    else
      name.gsub( "_", " ")
    end
  end

  def relative_path( from, to)
    from = from.split( "/")
    from = from[0...-1] if /\.(html|php|txt|md)$/ =~ from[-1]
    to = to.split( "/")
    while (to.size > 0) and (from.size > 0) and (to[0] == from[0])
      from = from[1..-1]
      to = to[1..-1]
    end
    rp = ((from.collect { ".."}) + to).join( "/")
    (rp == '') ? '.' : rp
  end
end