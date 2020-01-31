# frozen_string_literal: true

module SolidusSupport
  module EngineExtensions
    module Decorators
      def self.included(engine)
        engine.extend ClassMethods

        engine.class_eval do
          config.to_prepare(&method(:activate))

          enable_solidus_engine_support('backend') if SolidusSupport.backend_available?
          enable_solidus_engine_support('frontend') if SolidusSupport.frontend_available?
          enable_solidus_engine_support('api') if SolidusSupport.api_available?
        end
      end

      module ClassMethods
        def activate
          if Rails.respond_to?(:autoloaders) && Rails.autoloaders.main
            # Add decorators folder to the Rails autoloader. This tells Zeitwerk to treat paths
            # such as app/decorators/controllers as roots.
            solidus_decorators_root.glob('*') do |decorators_folder|
              Rails.autoloaders.main.push_dir(decorators_folder)
            end
          end

          load_solidus_decorators_from(solidus_decorators_root)
        end

        # Loads decorator files.
        #
        # This is needed since they are never explicitly referenced in the application code and
        # won't be loaded by default. We need them to be executed regardless in order to decorate
        # existing classes.
        def load_solidus_decorators_from(path)
          path.glob('**/*.rb') do |decorator_path|
            require_dependency(decorator_path)
          end
        end

        private

        # Returns the root for this engine's decorators.
        #
        # @return [Path]
        def solidus_decorators_root
          root.join('app/decorators')
        end

        # Enables support for a Solidus engine.
        #
        # This will tell Rails to:
        #
        #   * add +lib/controllers/[engine]+ to the controller paths;
        #   * add +lib/views/[engine]+ to the view paths;
        #   * load the decorators in +lib/decorators/[engine]+.
        #
        # @see #load_solidus_decorators_from
        def enable_solidus_engine_support(engine)
          paths['app/controllers'] << "lib/controllers/#{engine}"
          paths['app/views'] << "lib/views/#{engine}"

          engine_context = self
          config.to_prepare do
            engine_context.instance_eval do
              path = root.join("lib/decorators/#{engine}")
              load_solidus_decorators_from(path)
            end
          end
        end
      end
    end
  end
end
