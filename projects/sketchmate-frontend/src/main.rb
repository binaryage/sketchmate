# frozen_string_literal: true

require 'pry'
require 'socket'

# This is a quick and hacky solution.
# We monkey-patch Pry's eval and feed its inputs over a socket to Sketchup.

default_port = 4433
$sketchmate_port = Integer(ENV.fetch('SKETCHMATE_PORT', default_port)) rescue default_port
$sketchmate_host = ENV["SKETCHMATE_HOST"] || "localhost"

class Pry
  def eval(line, _options = {})
    timeout = 2
    socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    sockaddr = Socket.pack_sockaddr_in($sketchmate_port, $sketchmate_host)

    begin
      socket.connect_nonblock(sockaddr)
    rescue Errno::EINPROGRESS
      raise Timeout::Error unless IO.select(nil, [socket], nil, timeout)
      retry
    rescue Errno::EISCONN
      socket.write(line)
      socket.close_write
      out = socket.read
      output.print(out)
    rescue Errno::ECONNREFUSED => e
      puts e.message
    end
    true
  end

  def show_result(_result)
    # no op, we print the result on backend side
  end
end
