# frozen_string_literal: true

module Plumbing
  module Actor
    module Definitions
      # Defines three methods on the instance:
      #   `name` - this method can be called from outside of the actor, returning a message object that must be `await`ed to access the results
      #   `_name` - this method runs inside the actor's context and validates the parameters passed before calling...
      #   `_validated_#{name}_implementation` - this method actually runs the implementation of the method
      #
      # Example:
      #     class Greeting < Literal::Data
      #       include Plumbing::Actor
      #
      #       prop :name, String
      #
      #       async :say do
      #         param :greeting, String, default: "Hello"
      #         returns { "#{greeting} #{@name}" }
      #       end
      #     end
      #
      #     # Greeting has three methods - `say`, `_say` and `_validated_say_implementation`
      #     #   the latter two called internally within the actor's context
      #
      #     @greeting = Greeting.new name: "Alice"
      #     @result = @greeting.say "Hi there"
      #     puts @result.await # => "Hi there Alice"
      #     # ALTERNATIVE SYNTAX
      #     puts await { @greeting.say "Hi there" }
      def async name, &config
        method = MethodDefinition.new(name: name.to_sym)
        method.instance_eval(&config)
        raise ArgumentError, "async :#{name} requires a `returns { ... }` block" if method.implementation.nil?

        # external async method
        define_method name.to_sym do |sender: nil, **params, &block|
          worker.post name.to_sym, sender: sender, **params, &block
        end

        # internal validator
        define_method :"_#{name}" do |**params, &block|
          validated = method.params_class.new(**params).to_h
          send(impl_name, **validated, &block)
        end

        # internal implementation
        define_method(:"_validated_#{name}_implementation", &method.implementation)
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
