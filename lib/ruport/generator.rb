module Ruport
  class Generator
  extend FileUtils

  begin
    require "rubygems"
  rescue LoadError
    nil
  end
  require "ruport"

  def self.build(proj)
    @project = proj
    build_directory_structure
    build_init
    build_config
    build_utils         
    build_rakefile  
    puts "\nSuccessfully generated project: #{proj}"
  end

  def self.build_init
    m = "#{project}/lib/init.rb" 
    puts "  #{m}"
    File.open(m,"w") { |f| f << INIT }
  end

  # Generates a trivial rakefile for use with Ruport.
  def self.build_rakefile
    m = "#{project}/Rakefile"
    puts "  #{m}"
    File.open(m,"w") { |f| f << RAKEFILE }
  end

  # Generates the build.rb, sql_exec.rb, and cabinet.rb utilities
  def self.build_utils           
    
    m = "#{project}/util/build"   
    puts "  #{m}"
    File.open(m,"w") { |f| f << BUILD } 
    chmod(0755, m)
    
    m = "#{project}/util/sql_exec"  
    puts "  #{m}"
    File.open(m,"w") { |f| f << SQL_EXEC }
    chmod(0755, m)
  end

  # sets up the basic directory layout for a Ruport application
  def self.build_directory_structure
    mkdir project        
    puts "creating directories.."
    %w[ test config output data lib lib/reports 
        lib/renderers templates sql log util].each do |d|
      m="#{project}/#{d}" 
      puts "  #{m}"
      mkdir(m)
    end
    
    puts "creating files.."
    %w[reports helpers renderers].each { |f|
      m = "#{project}/lib/#{f}.rb"
      puts "  #{m}"
      touch(m)
    }
  end

  # Builds a file called config/ruport_config.rb which stores a Ruport::Config
  # skeleton
  def self.build_config
    m = "#{project}/config/ruport_config.rb"
    puts "  #{m}"
    File.open(m,"w") { |f| f << CONFIG }
  end

  # returns the project's name
  def self.project; @project; end

RAKEFILE = <<'END_RAKEFILE'
begin; require "rubygems"; rescue LoadError; end
require "rake/testtask"

task :default => [:test]

Rake::TestTask.new do |test|
  test.libs    << "test"
  test.pattern =  'test/**/test_*.rb'
  test.verbose =  true
end

task :build do
  if ENV['report']
    sh "ruby util/build report #{ENV['report']}"
  elsif ENV['renderer']
    sh "ruby util/build renderer #{ENV['renderer']}"
  end
end

task :run do
  sh "ruby lib/reports/#{ENV['report']}.rb"
end
END_RAKEFILE

CONFIG = <<END_CONFIG
require "ruport"

# For details, see Ruport::Config documentation
Ruport.configure { |c|
  c.source :default, :user     => "root", 
                     :dsn      =>  "dbi:mysql:mydb"
  c.log_file "log/ruport.log"
}
END_CONFIG

BUILD = <<'END_BUILD'
#!/usr/bin/env ruby

require 'fileutils'
include FileUtils

def format_class_name(string)
  string.downcase.split("_").map { |s| s.capitalize }.join
end

unless ARGV.length > 1
  puts "usage: build [command] [options]"
  exit
end

class_name = format_class_name(ARGV[1])

if ARGV[0].eql? "report"
  exit if File.exist? "lib/reports/#{ARGV[1]}.rb"
  File.open("lib/reports.rb", "a") { |f| 
    f.puts("require \"lib/reports/#{ARGV[1]}\"")
  }
REP = <<EOR
require "lib/init"
class #{class_name} < Ruport::Report
  
  def prepare

  end
 
  def generate

  end

  def cleanup

  end

end

if __FILE__ == $0
   #{class_name}.run { |res| puts res.results }
end
EOR

TEST = <<EOR
require "test/unit"
require "lib/reports/#{ARGV[1]}"

class Test#{class_name} < Test::Unit::TestCase
  def test_flunk
    flunk "Write your real tests here or in any test/test_* file"
  end
end
EOR
  raise "Renderer exists with same name!" if File.exist? "lib/renderers/#{ARGV[1]}"
  puts "report file: lib/reports/#{ARGV[1]}.rb"
  File.open("lib/reports/#{ARGV[1]}.rb", "w") { |f| f << REP }
  puts "test file: test/test_#{ARGV[1]}.rb"
  puts "class name: #{class_name}" 
  File.open("test/test_#{ARGV[1]}.rb","w") { |f| f << TEST }  
elsif ARGV[0].eql? "renderer"
  exit if File.exist? "lib/renderers/#{ARGV[1]}.rb"
  File.open("lib/renderers.rb","a") { |f|
    f.puts("require \"lib/renderers/#{ARGV[1]}\"")
  }
REP = <<EOR
require "lib/init"

class #{class_name} < Ruport::Renderer
  stage :#{class_name.downcase}
end

class #{class_name}Formatter < Ruport::Format::Plugin

  # change to your format name, or add additional formats
  renders :my_format, :for => #{class_name}

  def build_#{class_name.downcase}
  
  end

end
EOR

TEST = <<EOR
require "test/unit"
require "lib/renderers/#{ARGV[1]}"

class Test#{class_name} < Test::Unit::TestCase
  def test_flunk
    flunk "Write your real tests here or in any test/test_* file"
  end
end
EOR
  raise "Report exists with same name!" if File.exist? "lib/reports/#{ARGV[1]}"
  puts "renderer file: lib/renderers/#{ARGV[1]}.rb"
  File.open("lib/renderers/#{ARGV[1]}.rb", "w") { |f| f << REP }
  puts "test file: test/test_#{ARGV[1]}.rb"

  puts "class name: #{class_name}"
  File.open("test/test_#{ARGV[1]}.rb","w") { |f| f << TEST }
else
  puts "Incorrect usage."
end
END_BUILD

SQL_EXEC = <<'END_SQL'
#!/usr/bin/env ruby

require "lib/init"

puts Ruport::Query.new(ARGF.read).result
END_SQL

INIT = <<END_INIT
begin
  require "rubygems"
  gem "ruport","=#{Ruport::VERSION}"
rescue LoadError 
  nil
end
require "ruport"
require "lib/helpers"
require "lib/renderers"
require "config/ruport_config"

class String
  def /(other)
   self + "/" + other
  end
end

class Ruport::Report
  
  def output_dir
    config.output_dir or dir('output')
  end

  def data_dir
    config.data_dir or dir('data')
  end

  def query_dir
    config.query_dir or dir('sql')
  end

  def template_dir
    config.template_dir or dir('templates')
  end

  private
  def dir(name)
    "#{FileUtils.pwd}/#{ARGV[0]}/\#{name}"
  end
end
END_INIT


  end
end
