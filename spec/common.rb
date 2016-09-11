require 'rspec'
require 'open3'
require 'websocket'
require 'socket'
require 'json'
require_relative "spec_helper"


class ExternalProcess


	def initialize(command)
		@stdin,@stdout,@stderr,@thread = Open3.popen3(command)
		@stdout_buffer = ""
		@stderr_buffer = ""
		sleep 0.01 while @thread.status and @thread.status != 'sleep'
	end


	def kill
		ret = ''
		Process.kill('KILL',@thread.pid) rescue Errno::ESRCH if @thread.status
		Process.kill(9,@thread.pid) rescue Errno::ESRCH if @thread.status
		ret += stdout(true)
		ret += stderr(true)
		sleep 0.01 while @thread.status
		ret
	end


	def signal(name)
		Process.kill(name,@thread.pid)
	end


	def alive?
		@thread.status
	end


	def stdout(closing = false)
		sleep 0.1
		@stdout_buffer = ""
		@stdout_buffer += @stdout.read_nonblock(100000) while true
	rescue IO::EAGAINWaitReadable
		@stdout_buffer
	rescue EOFError
		return @stdout_buffer if closing
		raise "Server died"
	end


	def stderr(closing = false)
		sleep 0.1
		@stderr_buffer = ""
		@stderr_buffer += @stderr.read_nonblock(100000) while true
	rescue IO::EAGAINWaitReadable
		@stderr_buffer
	rescue EOFError
		return @stderr_buffer if closing
		raise "Server died"
	end

	def vmrss
		open('/proc/'+@thread.pid.to_s+'/status') { |f| f.read.lines.find {|line| line.start_with? 'VmRSS' } }.split[1].to_i
	end
end



class Server < ExternalProcess

	def initialize
		super("bundle exec ../bin/seapig-server debug")
		sleep 0.01 while not stdout =~ /Listening/
	end

end



class Client

	def initialize(server)
		@server = server
		@handshake = WebSocket::Handshake::Client.new(url: 'ws://127.0.0.1:3001')
		@socket = TCPSocket.open('127.0.0.1',3001)
		@socket.write(@handshake.to_s)
		@handshake << @socket.gets while not @handshake.finished?
		raise "Invalid handshake" if not @handshake.valid?
		@incoming = WebSocket::Frame::Incoming::Client.new(version: @handshake.version)
	end


	def kill
		@socket.close if not @socket.closed?
	end


	def send(data)
		frame = WebSocket::Frame::Outgoing::Client.new(version: @handshake.version, data: JSON.dump(data), type: :text)
		@socket.write(frame.to_s)
	end


	def messages(wait=0.05)
		ret = []
		t1 = Time.new
		while Time.new - t1 < wait
			begin
				data = @socket.read_nonblock(10000000)
				@incoming << data
			rescue IO::EAGAINWaitReadable
			rescue EOFError => e
				puts @server.kill
			raise 'Server died'
			end
		end

		while message = @incoming.next
			ret << message
		end

		raise "Client connection died" if ret[-1] and ret[-1].type == :close
		ret.select { |frame| frame.type == :text }.map { |frame| JSON.parse(frame.data) }
	end
end