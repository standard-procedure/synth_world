# frozen_string_literal: true

module Plumbing
  module Actor
    module Definitions
      def async name, &config
        method = MethodDefinition.new(name: name.to_sym)
        method.instance_eval(&config)
        raise ArgumentError, "async :#{name} requires a `returns { ... }` block" if method.implementation.nil?

        define_method name.to_sym do |sender: nil, **params, &block|
          worker.post name.to_sym, sender: sender, **params, &block
        end

        define_method :"_#{name}" do |**params, &block|
          validated = method.params_class.new(**params).to_h
          instance_exec(**validated, &method.implementation)
        end
      end

      class MethodDefinition < Literal::Struct
        include Literal::Types

        prop :name, Symbol, writer: false
        prop :implementation, _Callable?, writer: false
        prop :params_class, Class, writer: false, default: -> { Class.new(Literal::Struct) }

        def param(name, type, *rest, **opts)
          params_class.prop(name, type, *rest, **opts)
        end

        def returns(&implementation)
          @implementation = implementation
        end
      end
    end
  end
end
