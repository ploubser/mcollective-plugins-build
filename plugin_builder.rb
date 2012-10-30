# Proof on concept build class for mcollective plugins
class PluginBuilder
  # TODO : Write deploy code
  # TODO : Remove references to local files and directories
  # TODO : Move to a lib directory and write a real executable
  # TODO : Consider turning this into a gem
  # TODO : See if we need to add any other plugin types
  # TODO : Write tests for puppetlabs mcollective-plugins branch and stop skipping them
  require 'yaml'
  require 'pp'
  require 'rubygems'
  require 'mcollective'

  @@plugin_types = ["agent", "aggregate", "audit", "data", "facts", "registration", "security"]

  attr_accessor :to_build, :plugins, :plugin_dir, :failed_tests
  attr_accessor :failed_builds, :successful_tests, :successful_builds

  def initialize(plugin_dir)
    @failed_tests = []
    @successful_tests = []
    @failed_builds = []
    @successful_builds = []
    @plugin_dir = plugin_dir
    @plugins = plugins
    @build_list = to_build?
  end

  def version_from_ddl(plugin, type)
    begin
      MCollective::Cache.delete!(:ddl) rescue nil
      ddl = MCollective::DDL.new(plugin, type, false)
      # TODO : Read the correct file
      #ddl.instance_eval(File.read(File.join(File.expand_path(plugin), "#{plugin}.ddl")))
      ddl.instance_eval(File.read(Dir.glob(File.join(File.expand_path(plugin), type, "*.ddl"))[0]))
      version = ddl.meta[:version]
    rescue Exception => e
      puts "DDL file for plugin '#{plugin} could not be loaded - #{e}"
      return "0"
    end
  end

  # Determine which plugins should be built
  def to_build?
    build_list = []

    @plugins.each do |p|
      pname = name(p[0])
      config_file = File.join("/", "tmp", pname, "build.yaml")
      version = version_from_ddl(p[0], p[1])

      if File.exists?(config_file)
        config = YAML.load_file(config_file)
        if config[:version] < version
          config[:version] = version
          build_list << p
        end
      else
        config = {:version => version}
        build_list << p
        Dir.mkdir(File.join("/", "tmp", pname)) unless File.directory?(File.join("/", "tmp", pname))
      end
    end

    return build_list
  end

  # Determine list of plugin
  def plugins
    plugins = []
    plugin_types.each do |p|
      plugins += Dir.glob(File.join(@plugin_dir, p, "/*")).reject{|x|  !File.directory?(x)}.map{|x| [x, p]}
    end
    plugins
  end

  # Tests and builds all the plugins
  def build
    # Run the plugin's spec tests
    @plugins.each do |p|
      (test_plugin(p[0])) ? @successful_tests << p[0] : @failed_tests << p[0]
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

  def write_yaml(build_config, plugin)
    File.open(File.join(build_config), "w"){|f| f.write(plugin.to_yaml)}
  end

  # Run plugin spec tests
  def test_plugin(plugin)
    # Currently not all of the mcollective plugins have tests. For this proof of concept I'm going to skip
    # plugin's without tests but still build. See TODO
    test_result = system("rake test TARGETDIR=\"#{plugin}\"")
    return test_result
  end

  # Builds the plugin
  def build_plugin(plugin)
    build_result = system("rake buildplugin TARGETDIR=#{File.expand_path(plugin[0])} DESTDIR=\"/tmp/#{name(plugin[0])}\" MCBINDIR=\"#{File.join("/", "tmp", "marionette-collective")}\" MCLIBDIR=\"#{File.join("/", "tmp", "marionette-collective")}\" ")
    if build_result
      @successful_builds << plugin[0]
      config_file = File.join("/", "tmp", name(plugin[0]), "build.yaml")
      write_yaml(config_file, {:version => version_from_ddl(plugin[0], plugin[1])})
    else
      @failed_builds << plugin[0]
    end
  end

  # Determines plugin name from path
  def name(path)
    path.match(/^.*\/(.+)$/)
    $1
  end

  # Deploy plugin to server
  def deploy_plugin(plugin)
  end

  # Display a list of successful and failed tests/builds
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

a = PluginBuilder.new(File.dirname(__FILE__))
a.build
