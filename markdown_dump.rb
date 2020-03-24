#
# Process markdown file to give its structure and HTML output.
# Each node responds to sourcepos which gives a has like:
#
#  {:start_line=>1, :start_column=>1, :end_line=>7, :end_column=>9}
#
# Command line:
#   Input markdown file
#   Output structure dump
#   Output HTML
#
require 'commonmarker'

def dump_structure( node, indent, io)
  if node.type == :blockquote
    io.puts "#{indent}Blockquote:"
  elsif node.type == :document
    io.puts "#{indent}document:"
  elsif node.type == :emph
    io.puts "#{indent}Emph:"
  elsif node.type == :header
    io.puts "#{indent}Header: #{node.header_level}"
  elsif node.type == :link
    io.puts "#{indent}Link: url=#{node.url} title=#{node.title}"
  elsif node.type == :paragraph
    io.puts "#{indent}Paragraph:"
  elsif node.type == :softbreak
    io.puts "#{indent}Softbreak:"
  elsif node.type == :strong
    io.puts "#{indent}Strong:"
  elsif node.type == :text
    io.puts "#{indent}Text: #{node.string_content}"
  else
    raise "Unhandled node type: #{node.type}"
  end

  node.each do |child|
    dump_structure( child, indent + '  ', io)
  end
end

doc = CommonMarker.render_doc( IO.read( ARGV[0]))
File.open( ARGV[1], 'w') do |io|
  dump_structure( doc, '', io)
end

File.open( ARGV[2], 'w') {|io| io.puts( doc.to_html( :SOURCEPOS))}