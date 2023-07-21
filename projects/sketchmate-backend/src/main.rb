# frozen_string_literal: true

require 'socket'
require 'stringio'

# pry has some assumptions about $stdout during initialization in config.rb,
# Sketchup does not play along, let's work around it
prev_stdout = $stdout
$stdout = StringIO.new
require 'pry'
$stdout = prev_stdout

$sketchmate_verbose = ENV.key?("SKETCHMATE_VERBOSE")
default_port = 4433
port = Integer(ENV.fetch('SKETCHMATE_PORT', default_port)) rescue default_port

$sketchmate_driver = nil

class SketchMateDriver < Pry::REPL
  def initialize(pry, options = {})
    super(pry, options)
  end

  def start
    $sketchmate_driver = self
    puts "SKETCHMATE: PRY driver started." if $sketchmate_verbose
  end
end

class Pry
  class Output
    def readline_size
      nil
    end
  end
end

# mimic RubyMine pry setup

pry_out = StringIO.new
pry_input = StringIO.new

prompt_procs = [proc { '>>' }, proc { '?>' }]
prompt_descr = 'Simple {`>>`|`?>`} prompt for Pry Run Configurations'

pry_options = {
  driver: SketchMateDriver,
  input: pry_input,
  output: pry_out,
  prompt: Pry::Prompt.new('RM', prompt_descr, prompt_procs),
  prompt_name: 'RM',
  color: false,
  pager: false,
  auto_indent: false,
  correct_indent: false,
  completer: nil,
  command_completions: nil,
  file_completions: nil
}

Pry.start(self, pry_options)

puts "SKETCHMATE: Launching local TCP server on port #{port}." if $sketchmate_verbose
server = TCPServer.new(port)

def with_captured_output(output)
  begin
    prev_stdout = $stdout
    prev_stderr = $stderr
    $stdout = output
    $stderr = output
    yield
  ensure
    $stdout = prev_stdout
    $stderr = prev_stderr
  end
end

UI.start_timer(0.1, true) do
  begin
    loop do
      connection = server.accept_nonblock
      message = connection.read # blocking read

      if message
        # puts "SKETCHMATE: Received '#{message.chomp}'."
        pry = $sketchmate_driver.pry
        pry.output.reopen
        with_captured_output(pry.output) do
          pry.eval(message)
        end
        pry.output.rewind
        result = pry.output.read
        connection.write(result)
        connection.close_write
      end

      connection.close
    end
  rescue Errno::EWOULDBLOCK
    # no connection avail
  rescue Errno::EAGAIN
    # no connection avail
  end
rescue StandardError => e
  puts "SKETCHMATE: !!! #{e}"
end
