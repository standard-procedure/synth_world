# frozen_string_literal: true

module Plumbing
  module Actor
    module Definitions
      def async name, &config
        method = MethodDefinition.new(name: name.to_sym)
        method.instance_eval(&config)
        raise ArgumentError, "async :#{name} requires a `returns { ... }` block" if method.implementation.nil?

        # Define the implementation as a real method on the host class so that
        # the user-supplied block at the call site flows through to it as the
        # method's block (accessible via `&block` in the `returns` signature).
        # `instance_exec` can't forward a block separately from the proc-as-block,
        # so we use `define_method`-with-proc instead.
        impl_name = :"_validated_#{name}_implementation"
        define_method(impl_name, &method.implementation)

        define_method name.to_sym do |sender: nil, **params, &block|
          worker.post name.to_sym, sender: sender, **params, &block
        end

        define_method :"_#{name}" do |**params, &block|
          validated = method.params_class.new(**params).to_h
          send(impl_name, **validated, &block)
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
