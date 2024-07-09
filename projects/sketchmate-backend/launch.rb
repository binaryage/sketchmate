# frozen_string_literal: true

verbose = ENV.has_value?("SKETCHMATE_VERBOSE")

puts "SKETCHMATE: Loading backend from '#{__dir__}'." if verbose

# I want to require pry gem (including its dependencies)
# I decided to use bundler to download and manage gems, but we do custom loading here.
#
# I don't want to
# require 'bundler/setup'
#
# It did not work for me in Sketchup's context and it seems to do a lot of monkey business.
# AFAICT Sketchup is not compatible with bundler and using gems is tricky.
#
# Our strategy:
# Bundler should be configured to install gems locally into ./vendor/ruby/<version>/gems (see BUNDLE_PATH in .bundle/config)
# We add load paths for known dependencies by hand by searching ./vendor dir.
# <version> should be 3.2.2
# or whatever is current internal bundled Ruby version with Sketchup, see RUBY_VERSION in the console.
# Ideally you should use rbenv or similar to match that.
# I personally prefer to use direnv, which is already configured to use .ruby-version.

# TODO: In the future after Sketchup bumps ruby to 3.2+ we want to use something like https://github.com/shioyama/im

script_dir = __dir__
if script_dir.nil?
  raise "Unexpected launch conditions"
end

our_known_deps = %w[pry coderay method_source]
vendor_ruby_path = File.expand_path('vendor/ruby', script_dir)
preferred_ruby_version = RUBY_VERSION

def resolve_load_paths_for_deps(vendor_ruby_path, preferred_ruby_version, deps)
  unless File.exist?(vendor_ruby_path)
    puts "SKETCHMATE: Unable to locate/access vendor ruby dir at '#{vendor_ruby_path}'."
    puts "SKETCHMATE: Did you run `bundle install` in sketchmate-backend?"
    raise "Unable to locate/access vendor Ruby dir"
  end

  selected_vendor_ruby_path = File.join(vendor_ruby_path, preferred_ruby_version)
  unless File.exist?(selected_vendor_ruby_path)
    puts "SKETCHMATE: You should be using rbenv with Ruby version #{preferred_ruby_version}. This setup might break." if $sketchmate_verbose
    selected_vendor_ruby_path = Dir["#{vendor_ruby_path}/*"].first
    if selected_vendor_ruby_path.nil?
      puts "SKETCHMATE: You have no rubies installed in the vendor dir."
      puts "SKETCHMATE: Did you run `bundle install` in sketchmate-backend?"
      raise "No rubies installed in the vendor dir"
    end
  end

  selected_gems_path = File.join(selected_vendor_ruby_path, "gems")
  all_good = true
  lib_paths = deps.map do |dep|
    gem_glob = File.join(selected_gems_path, "#{dep}-*")
    # for simplicity just grab first available version, it is responsibility of our user to have clean gems
    found_gem = Dir[gem_glob].first
    if found_gem.nil?
      puts "SKETCHMATE: Unable to find gem in vendor directory '#{gem_glob}'."
      all_good = false
      next
    end
    File.join(found_gem, "lib")
  end

  unless all_good
    raise "Some dependencies were not found"
  end

  lib_paths.compact
end

deps_paths = resolve_load_paths_for_deps(vendor_ruby_path, preferred_ruby_version, our_known_deps)
$LOAD_PATH.push(*deps_paths)

def replace_extension(file_path, new_extension)
  File.join(File.dirname(file_path), "#{File.basename(file_path, ".*")}.#{new_extension}")
end

# convenience feature: load script named after active model if exists
# /some/path/my_model.skp will try to load /some/path/my_model.rb
model_path = Sketchup.active_model.path
unless model_path.nil?
  model_init_script_file = replace_extension(model_path, "rb")
  if File.exist?(model_init_script_file)
    puts "SKETCHMATE: Loading '#{model_init_script_file}'." if verbose
    load model_init_script_file
  end
end

# require backend code
require_relative 'src/main'