# Proof on concept build class for mcollective plugins
class PluginBuilder
  # TODO : Write deploy code
  # TODO : Remove references to local files and directories
  # TODO : Move to a lib directory and write a real executable
  # TODO : Consider turning this into a gem
  # TODO : DDL types are being hardcoded when loaded. Fix.
  require 'yaml'
  require 'pp'
  require 'rubygems'
  require 'mcollective'

  @@plugin_types = ["agent"]

  attr_accessor :to_build, :plugins, :plugin_dir, :user_dir, :failed_tests
  attr_accessor :failed_builds, :successful_tests, :successful_builds

  def initialize(plugin_dir, user_dir)
    @failed_tests = []
    @successful_tests = []
    @failed_builds = []
    @successful_builds = []
    @plugin_dir = plugin_dir
    @user_dir = user_dir
    @plugins = plugins
    @build_list = to_build?
  end

  # Determine which plugins should be built
  def to_build?
    build_list = []
    version = "0"

    @plugins.each do |p|
      begin
        p.match(/^.*\/(.+)$/)
        pname = $1
        ddl = MCollective::DDL.new(pname, :agent, false)
        ddl.instance_eval(File.read(File.join(File.expand_path(p), "agent", "#{pname}.ddl")))
        version = ddl.meta[:version]

      rescue Exception => e
        puts "could not find ddl file '#{pname}.ddl' - #{e}"
      end

      config_file = File.join("/", "tmp", pname, "build.yaml")

      if File.exists?(config_file)
        config = YAML.load_file(config_file)
        if config[:version] < version
          config[:version] = version
          build_list << p
          write_yaml(config_file, config)
        end
      else
        config = {:version => version}
        build_list << p
        Dir.mkdir(File.join("/", "tmp", pname)) unless File.directory?(File.join("/", "tmp", pname))
        write_yaml(config_file, config)
      end
    end

    return build_list
  end

  # Determine list of plugin
  def plugins
    plugins = []
    plugin_types.each do |p|
      plugins += Dir.glob(File.join(@plugin_dir, p, "/*")).reject{|x|  !File.directory?(x)}
    end
    plugins
  end

  # Tests and builds all the plugins
  def build
    # Run the plugin's spec tests
    @plugins.each do |p|
      (test_plugin(p)) ? @successful_tests << p : @failed_tests << p
    end

    # Remove all plugins with failed tests from the build list
    @build_list -= @failed_tests

    # Build the plugins with successful tests
    @build_list.each do |p|
      build_plugin(p)
    end

    results
  end

  def plugin_types
    return @@plugin_types
  end

  :private

  def write_yaml(build_config, plugins)
    File.open(File.join(build_config), "w"){|f| f.write(plugins.to_yaml)}
  end

  # Run plugin spec tests
  def test_plugin(plugin)
    test_result = system("rake test TARGETDIR=\"#{plugin}\"")
    return test_result
  end

  # Builds the plugin
  def build_plugin(plugin)
    build_result = system("rake buildplugin TARGETDIR=#{plugin} DESTDIR=\"/tmp/plugins\" MCBASEDIR=\"#{File.join("/", "tmp", "marionette-collective")}\" ")
    (build_result) ? @successful_builds << plugin : @failed_builds << plugin
  end

  # Deploy plugin to server
  def deploy_plugin(plugin)
  end

  def results
    puts
    puts "-------------------------------------------"
    puts "Finished building MCollective Plugins"
    puts "Successful tests - #{@successful_tests.size}"
    puts "Failed tests - #{@failed_tests.size}"
    puts "Successful builds - #{@successful_builds.size}"
    puts "Failed builds - #{@failed_builds.size}"
    if @failed_tests.size + @failed_builds.size > 0
      exit 1
    else
      exit 0
    end
  end
end

a = PluginBuilder.new(File.dirname(__FILE__), "/home/vagrant")
a.build
