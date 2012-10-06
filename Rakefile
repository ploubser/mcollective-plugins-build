specdir = File.join([File.dirname(__FILE__), "spec"])

require "#{specdir}/spec_helper.rb"
require 'rake'
require 'rspec/core/rake_task'

def safe_system *args
  raise RuntimeError, "Failed: #{args.join(' ')}" unless system *args
end

def check_build_env
  raise "Not all environment variables have been set. Missing #{{"'DESTDIR'" => ENV["DESTDIR"], "'MCBASEDIR'" => ENV["MCBASEDIR"], "'TARGETDIR'" => ENV["TARGETDIR"]}.reject{|k,v| v != nil}.keys.join(", ")}" unless ENV["DESTDIR"] && ENV["MCBASEDIR"] && ENV["TARGETDIR"]
  raise "DESTDIR - '#{ENV["DESTDIR"]}' is not a directory" unless File.directory?(ENV["DESTDIR"])
  raise "MCBASEDIR - '#{ENV["MCBASEDIR"]}' is not a directory" unless File.directory?(ENV["MCBASEDIR"])
  raise "TARGETDIR - '#{ENV["TARGETDIR"]}' is not a directory" unless File.directory?(ENV["TARGETDIR"])
end


def build_package(path)
  options = []

  if File.directory?(path)
    buildops = File.join(path, "buildops.yaml")
    buildops = YAML.load_file(buildops) if File.exists?(buildops)

    return unless buildops["build"]

    libdir = buildops["mclibdir"] || ENV["LIBDIR"]
    mcname = buildops["mcname"] || ENV["MCNAME"]
    sign = buildops["sign"] || ENV["SIGN"]

    options << "--pluginpath=#{libdir}" if libdir
    options << "--mcname=#{mcname}" if mcname
    options << "--sign" if sign

    options << "--dependency=\"#{buildops["dependencies"].join(" ")}\"" if buildops["dependencies"]

    safe_system("ruby -I #{File.join(ENV["MCBASEDIR"], "lib")} #{File.join(ENV["MCBASEDIR"], "bin", "mco")} plugin package #{path} #{options.join(" ")}")
    safe_system("mv *.rpm #{ENV["DESTDIR"]}") unless File.expand_path(ENV["DESTDIR"]) == Dir.pwd
  end
end

desc "Build packages for specified plugin in target directory"
task :buildplugin do
  check_build_env
  build_package(ENV["TARGETDIR"])
end

desc "Build packages for all plugins in target directory"
task :build do
  check_build_env
  packages = Dir.glob(File.join(ENV["TARGETDIR"], "*"))

  packages.each do |package|
    if File.directory?(File.expand_path(package))
      build_package(File.expand_path(package))
    end
  end
end

desc "Run agent and application tests"
RSpec::Core::RakeTask.new(:test) do |t|
  if ENV["TARGETDIR"]
    t.pattern = "#{File.expand_path(ENV["TARGETDIR"])}/spec/*_spec.rb"
  else
    t.pattern = 'agent/**/spec/*_spec.rb'
  end

  t.rspec_opts = $LOAD_PATH.join(" -I ") + " " + File.read("#{specdir}/spec.opts").chomp
end

task :default => :test
