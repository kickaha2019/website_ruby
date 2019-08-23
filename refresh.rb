=begin
	refresh.rb

	Refresh expected files from what's generated
=end

load 'test.rb'

class CompilerTest
	
	def expect( dir, expected, got)
		exp_path = path( dir, expected)
		got_path = path( dir, got)
		
		if not FileUtils.compare_file( exp_path, got_path)
			raise "Error copying" if not system( "cp #{got_path} #{exp_path}") 
			raise "Mismatch between #{expected} and #{got}"
		end
	end
end
