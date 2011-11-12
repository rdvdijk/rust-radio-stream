require 'thor'

module RustRadio
  class CLI < Thor

    desc "add_show [PATH]", "Add a show to the default playlist."
    method_option :playlist, :type => :string, :default => "Default"
    def add_show(path)
      raise Thor::MalformattedArgumentError.new("#{path} does not exist.") unless File.exists?(path)
      raise Thor::MalformattedArgumentError.new("#{path} is not a directory.") unless File.directory?(path)
      puts "Adding folder: #{path}"
      RustRadio::ShowAdder.new.add(path, options["playlist"])
    end

    desc "clear", "Remove all shows (just don't!)."
    method_options :really => :boolean
    def clear
      DataMapper.auto_migrate! if options["really"]
    end

    desc "play", "Start the stream."
    method_option :config_file, :type => :string, :default => "config/config.yml"
    def play
      RustRadio::Radio.new(options["config_file"]).play
    end

    desc "web", "Start webserver."
    def web
      RustRadio::Web::UI.run!
    end
  end
end
