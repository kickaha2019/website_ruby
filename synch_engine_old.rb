=begin
	synch_engine.rb

	Engine for synching local site to remote site
=end

require 'FileUtils'

class SynchEngine

    # Initialisation
    def initialize( args = {})
        @temp = 0
        check_set( @local_root = args[:local_root])
        check_set( @shadow_root = args[:shadow_root])
        check_set( @remote_address = args[:remote_address])
        check_set( @remote_root = args[:remote_root])
        check_set( @wanted_types = args[:wanted_types])
        check_set( @exclude_paths = args[:exclude_paths])
    end
    
# =================================================================
# Main logic
# =================================================================

	# Run the synch
	def run( path="", limit=999999)
        raise "Limit hit" if limit<1
        limit = limit - 1
        local = list_dir( @local_root + path)
        shadow = list_dir( @shadow_root + path)
        
        # New files in local directory
        (local - shadow).each do |file|
            path1 = path + "/" + file
            next if not wanted_path?( path1)
            
            if File.directory?( @local_root + path1)
                ftp_make_dir( @remote_root + path1)
                Dir.mkdir( @shadow_root + path1)
                limit = run( path1, limit)
            elsif wanted_file?( path1)
                ftp_put( @local_root + path1, @remote_root + path1)
                new_time = File.mtime( @local_root + path1).to_i
                f = File.new( @shadow_root + path1, "w")
                f.write( new_time.to_s)
                f.close
            end
        end
        
        # Files removed from local directory
        (shadow - local).each do |file|
            path1 = path + "/" + file
            
            ftp_delete( @remote_root + path1)
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
                limit = run( path1, limit)
            elsif File.exists?( timestamp)
                new_time = File.mtime( local).to_i
                old_time = IO.readlines( timestamp)[0].to_i
                if new_time != old_time 
                    if not system( "cmp -s " + local + " " + shadow)
                        ftp_put( local, @remote_root + path1)
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
                    ftp_put( local, @remote_root + path1)
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
		puts "ftp_put: #{dest}"
		ftp_command( "sftp", "put #{source} #{dest}", temp_log)
	end
	
	# FTP make dir
	def ftp_make_dir( dir)
		puts "ftp_make_dir: #{dir}"
		ftp_command( "ssh", "mkdir #{dir}", temp_log)
	end
	
	# FTP delete file
	def ftp_delete( dest)
		puts "ftp_delete: #{dest}"
		ftp_command( "ssh", "rm -r #{dest}", temp_log)
	end
	
	# Execute FTP command
	def ftp_command( verb, cmd, log_file)
        f = File.new( "/tmp/ftp.txt","w")
        f.puts cmd
        f.close

        #puts "sh -c '#{verb} #{@remote_address} -b /tmp/ftp.txt >#{log_file}'"
        #raise "test"

        system( "#{verb} #{@remote_address} </tmp/ftp.txt >&#{log_file}")
        
        IO.readlines( log_file).each do |line|
            next if /^\s*$/ =~ line
            #next if /^Last login: / =~ line
            #next if /^spawn sftp / =~ line
            #next if /^spawn ssh / =~ line
            #next if /^Connection closed/ =~ line
            #next if /^Connection to .* closed/ =~ line
            #next if /^Connecting to/ =~ line
            next if /^Connected to/ =~ line
            #next if /^Password: / =~ line
            #next if /^put / =~ line
            #next if /^logout/ =~ line
            next if /^Pseudo-terminal will not / =~ line
            next if /^Uploading / =~ line
            #next if /^\s*\// =~ line
            next if /^mkdir: cannot create directory/ =~ line
			next if /^The programs included / =~ line
			next if /^the exact distribution terms / =~ line
			next if /^individual files in / =~ line
			next if /^Debian GNU\/Linux comes / =~ line
			next if /^permitted by applicable law/ =~ line
            #next if /^Permission denied \(publickey\,keyboard-interactive\)\./ =~ line
            next if /^sftp>/ =~ line
#                prompt = prompt + 1
#            elsif /\:\~\$/ =~ line
#                prompt = prompt + 1
#            else
             puts "Error: #{line}"
             raise "See log file #{log_file}"
#            end
        end
	end
	
	# Return name of temp log file
    def temp_log
        @temp = @temp + 1
		"/tmp/synch_#{@temp.to_s}.log"
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
