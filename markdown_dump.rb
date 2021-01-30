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
  elsif node.type == :code_block
    io.puts "#{indent}Codeblock: #{node.fence_info}"
    node.string_content.split("\n").each do |line|
      io.puts "#{indent}  #{line}"
    end
  elsif node.type == :document
    io.puts "#{indent}Document:"
  elsif node.type == :emph
    io.puts "#{indent}Emph:"
  elsif node.type == :header
    io.puts "#{indent}Header: #{node.header_level}"
  elsif node.type == :html
    io.puts "#{indent}HTML: #{node.string_content}"
  elsif node.type == :image
    io.puts "#{indent}Image: url=#{node.url} title=#{node.title}"
  elsif node.type == :inline_html
    io.puts "#{indent}Inline HTML:"
  elsif node.type == :link
    io.puts "#{indent}Link: url=#{node.url} title=#{node.title}"
  elsif node.type == :paragraph
    io.puts "#{indent}Paragraph:"
  elsif node.type == :softbreak
    io.puts "#{indent}Softbreak:"
  elsif node.type == :strong
    io.puts "#{indent}Strong:"
  elsif node.type == :table
    io.puts "#{indent}Table:"
  elsif node.type == :table_cell
    io.puts "#{indent}Table cell:"
  elsif node.type == :table_header
    io.puts "#{indent}Table header:"
  elsif node.type == :table_row
    io.puts "#{indent}Table row:"
  elsif node.type == :text
    io.puts "#{indent}Text: #{node.string_content}"
  else
    raise "Unhandled node type: #{node.type}"
  end

  node.each do |child|
    dump_structure( child, indent + '  ', io)
  end
end

doc = CommonMarker.render_doc( IO.read( ARGV[0]), [:DEFAULT], [:table])
File.open( ARGV[1], 'w') do |io|
  dump_structure( doc, '', io)
end

File.open( ARGV[2], 'w') {|io| io.puts( doc.to_html( :SOURCEPOS))}