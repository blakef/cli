# This is a function which is used inside your Podfile.
#
# list_native_modules!(project_root) and returns the hash needed by 
# init_native_modules! in @react-native/core-cli-utils/autolinking/ios/native_modules.rb#link_native_modules

require 'pathname'
require 'cocoapods'

require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "@react-native/core-cli-utils/autolinking/pods.rb",
    {paths: [process.argv[1]]},
  )', __dir__]).strip


def list_native_modules!(project_root)
  cli_bin = Pod::Executable.execute_command("node", ["-e",  "require('@react-native-community/cli').bin)"], true).strip

  json = []

  IO.popen(["node", cli_bin, "config"]) do |data|
    while line = data.gets
      json << line
    end
  end

  config = JSON.parse(json.join("\n"))

  project_root = Pathname.new(config["project"]["ios"]["sourceDir"])

  packages = config["dependencies"]
  found_pods = []

  packages.each do |package_name, package|
    next unless package_config = package["platforms"]["ios"]

    podspec_path = package_config["podspecPath"]
    configurations = package_config["configurations"]

    # Add a warning to the queue and continue to the next dependency if the podspec_path is nil/empty
    if podspec_path.nil? || podspec_path.empty?
      Pod::UI.warn("list_native_modules! skipped the react-native dependency '#{package["name"]}'. No podspec file was found.",
        [
          "Check to see if there is an updated version that contains the necessary podspec file",
          "Contact the library maintainers or send them a PR to add a podspec. The react-native-webview podspec is a good example of a package.json driven podspec. See https://github.com/react-native-community/react-native-webview/blob/master/react-native-webview.podspec",
          "If necessary, you can disable autolinking for the dependency and link it manually. See https://github.com/react-native-community/cli/blob/main/docs/autolinking.md#how-can-i-disable-autolinking-for-unsupported-library"
        ])
    end
    next if podspec_path.nil? || podspec_path.empty?

    spec = Pod::Specification.from_file(podspec_path)

    # Skip pods that do not support the platform of the current target.
    if platform = current_target_definition.platform
      next unless spec.supported_on_platform?(platform.name)
    else
      # TODO: In a future RN version we should update the Podfile template and
      #       enable this assertion.
      #
      # raise Pod::Informative, "Cannot invoke `!` before defining the supported `platform`"
    end

    podspec_dir_path = Pathname.new(File.dirname(podspec_path))

    relative_path = podspec_dir_path.relative_path_from project_root

    # pod spec.name, :path => relative_path.to_path, :configurations => configurations

    found_pods.push {
      :name => name,
      :relative_path => relative_path.to_path,
      :configurations => configurations
    }
  end

  if found_pods.size > 0
    pods = found_pods.map { |p| p.name }.sort.to_sentence
    Pod::UI.puts "Found #{found_pods.size} #{"module".pluralize(found_pods.size)} for target `#{current_target_definition.name}`"
  end
  
  absolute_react_native_path = Pathname.new(config["reactNativePath"])

  { 
    :reactNativePath => absolute_react_native_path.relative_path_from(project_root).to_s,
    :pods => found_pods
  }
end

require_relative './native_modules.rb'
