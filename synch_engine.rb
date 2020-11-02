=begin
	synch_engine.rb

	Generate scripts for synching local site to remote site
=end

require 'FileUtils'

class SynchEngine

    # Initialisation
    def initialize( args = {})
      @temp = 0
      check_set( @local_root = args[:local_root])
      check_set( @shadow_root = args[:shadow_root])
      check_set( @remote_root = args[:remote_root])
      check_set( @wanted_types = args[:wanted_types])
      check_set( @exclude_paths = args[:exclude_paths])
      @tar_script = File.open( '/tmp/tar.txt', 'w')
      @ssh_script = File.open( '/tmp/ssh.txt', 'w')
      @ssh_script.puts "cd #{@remote_root}"
      @ssh_script.puts "tar -xvf ../website.tar"
      @ssh_script.puts "rm ../website.tar"
    end
    
# =================================================================
# Main logic
# =================================================================

	def run
		process( "", 999999)
		@ssh_script.close
		@tar_script.close
		raise "Tar creation failed" if not system( "tar -T /tmp/tar.txt -s :#{@local_root}:: -cvf /tmp/website.tar")
	end
	
	# Run the synch
	def process( path, limit)
        raise "Limit hit" if limit<1
        limit = limit - 1
        local = list_dir( @local_root + path)
        shadow = list_dir( @shadow_root + path)
        
        # New files in local directory
        (local - shadow).each do |file|
            path1 = path + "/" + file
            next if not wanted_path?( path1)
            
            if File.directory?( @local_root + path1)
                ftp_make_dir( path1)
                Dir.mkdir( @shadow_root + path1)
                limit = process( path1, limit)
            elsif wanted_file?( path1)
                ftp_put( @local_root + path1, path1)
                new_time = File.mtime( @local_root + path1).to_i
                f = File.new( @shadow_root + path1, "w")
                f.write( new_time.to_s)
                f.close
            end
        end
        
        # Files removed from local directory
        (shadow - local).each do |file|
            path1 = path + "/" + file
            
            ftp_delete( path1)
            if File.directory?( @shadow_root + path1)
                FileUtils.remove_dir( @shadow_root + path1)
            else
                FileUtils.remove_file( @shadow_root + path1)
            end
        end
        
        # Possible changes
        (local & shadow).each do |file|
            path1 = path + "/" + file
            local = @local_root + path1
            shadow = @shadow_root + path1
            timestamp = shadow + ".timestamp"
            
            if File.directory?( local)
                limit = process( path1, limit)
            elsif File.exists?( timestamp)
                new_time = File.mtime( local).to_i
                old_time = IO.readlines( timestamp)[0].to_i
                if new_time != old_time 
                    if not system( "cmp -s " + local + " " + shadow)
                        ftp_put( local, path1)
                        raise "Copy failed" if not system( "cp " + local + " " + shadow)
                    end
                    f = File.new( timestamp, "w")
                    f.write( new_time.to_s)
                    f.close
                end
            else
                new_time = File.mtime( local).to_i
                old_time = IO.readlines( shadow)[0].to_i
                if new_time != old_time
                    ftp_put( local, path1)
                    f = File.new( timestamp, "w")
                    f.write( new_time.to_s)
                    f.close
                    raise "Copy failed" if not system( "cp " + local + " " + shadow)
                end
            end
        end
        
        limit
    end

# =================================================================
# Methods for sftp and ssh operations on remote site
# =================================================================
	
	# FTP put file
	def ftp_put( source, dest)
		@tar_script.puts source
	end
	
	# FTP make dir
	def ftp_make_dir( dir)
		#@sftp_script.puts "mkdir #{dir[1..-1]}"
		#@sftp_script.flush
	end
	
	# FTP delete file
	def ftp_delete( dest)
		@ssh_script.puts "rm -r #{dest[1..-1]}"
	end
	
# =================================================================
# Helper methods
# =================================================================

	# List files in a directory
	def list_dir( path)
		files = []
		d = Dir.new( path)
		d.each { |file|
			next if file == "." or file == ".."
            next if file == ".DS_Store"
            next if /\.timestamp$/ =~ file
            if / / =~ file
                raise "Spaces in name at #{path}/#{file}"
            end
			files.push( file)
		}
		d.close	
		files
	end
    
    # Check for wanted path
    def wanted_path?( path)
        @exclude_paths.each do |ep|
            return false if Regexp.new( "^/" + ep + "(/.*|)$") =~ path
        end
        true
    end
    
    # Check for wanted file
    def wanted_file?( path)
        return false if not wanted_path?( path)
        if m = /\.([^\.]*)$/.match( path)
            return @wanted_types.index( m[1].downcase)
        end
        false
    end
    
    # Check variable set
    def check_set( value)
        raise "Not set" if not value
    end
end
