class PluginBuilder
  #TODO : Write deploy code
  require 'yaml'
  require 'pp'

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
    build_config = File.join(@user_dir, "buildconfig.yaml")
    build_list = []

    if File.exists?(build_config)
      config = YAML.load_file(build_config)
      version = "0"

      @plugins.each do |p|
        begin
          version = YAML.load_file(File.join(p, "buildops.yaml"))["version"] || "0"
        rescue Exception => e
          puts "buildops file not found for plugin #{p}. Using version number 0"
        end

        unless config.keys.include?(p)
          build_list << p
          config[p] = version
          next
        end

        if config[p] <= version
          build_list << p
          config[p] = version
        end

      end
      write_yaml(build_config, config)

      return build_list
    else
      plugins = {}

      @plugins.each do |p|
        plugins[p] = YAML.load_file(File.join(p, "buildops.yaml"))["version"] || "0"
      end

      write_yaml(build_config, plugins)
      return plugins.keys
    end
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
    build_result = system("rake buildplugin TARGETDIR=#{plugin} DESTDIR=\"/home/psy/testbuilds\" MCBASEDIR=\"/home/psy/marionette-collective\" ")
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
    if @failed_tests.size + @failed_builds > 0
      exit 1
    else
      exit 0
    end
  end
end

a = PluginBuilder.new("/home/psy/mcollective-plugins-build", "/home/psy")
a.build
