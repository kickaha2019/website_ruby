=begin
	run.rb

	Generate HTML structure from article files
	
	Command line:

	Cache directory
	Source directory
	Target directory
=end

load 'Compiler.rb'

compiler = Compiler.new( * ARGV)
#puts compiler.encode_special_chars( "“")
#begin
	compiler.compile
#rescue Exception => bang
#	puts bang.message
#	puts bang.backtrace.join( "\n")
#	exit 1
#end

exit 1 if compiler.errors?
