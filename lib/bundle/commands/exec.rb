# frozen_string_literal: true

require "exceptions"
require "extend/ENV"
require "utils"

module Bundle
  module Commands
    module Exec
      module_function

      def run(*args, global: false, file: nil)
        # Setup Homebrew's ENV extensions
        ENV.activate_extensions!
        raise UsageError, "No command to execute was specified!" if args.blank?

        command = args.first

        # For commands which aren't either absolute or relative
        if command.exclude? "/"
          # Save the command path, since this will be blown away by superenv
          command_path = which(command)
          raise "command was not found in your PATH: #{command}" if command_path.blank?

          command_path = command_path.dirname.to_s
        end

        brewfile = Bundle::Dsl.new(Brewfile.read(global: global, file: file))

        require "formula"
        require "formulary"

        ENV.deps = brewfile.entries.map do |entry|
          next if entry.type != :brew

          f = Formulary.factory(entry.name)
          [f, f.recursive_dependencies.map(&:to_formula)]
        end.flatten.compact
        ENV.keg_only_deps = ENV.deps.select(&:keg_only?)
        ENV.setup_build_environment

        # Enable compiler flag filtering
        ENV.refurbish_args

        # Setup pkg-config, if present, to help locate packages
        pkgconfig = Formulary.factory("pkg-config")
        ENV.prepend_path "PATH", pkgconfig.opt_bin.to_s if pkgconfig.any_version_installed?

        # Ensure the Ruby path we saved goes before anything else, if the command was in the PATH
        ENV.prepend_path "PATH", command_path if command_path.present?

        exec(*args)
      end
    end
  end
end
