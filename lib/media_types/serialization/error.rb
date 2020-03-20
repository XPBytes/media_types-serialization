
module MediaTypes
  module Serialization
    class Error < StandardError
    end

    class ControlFlowError < Error
    end

    class InputNotAcceptableError < ControlFlowError
      def initialize
        super('Content-Type provided in the request is not acceptable.')
      end
    end

    class RuntimeError < Error
    end

    class NoInputReceivedError < RuntimeError
      def initialize
        super('No Content-Type specified in request.')
      end
    end

    class InputValidationFailedError < RuntimeError
      def initialize(inner)
        @inner = inner
        super(inner.message)
      end
    end
    
    class OutputValidationFailedError < RuntimeError
      def initialize(inner)
        @inner = inner
        super(inner.message)
      end
    end

    class ConfigurationError < Error
    end

    class CannotDecodeOutputError < ConfigurationError
      def initialize
        super('Unable to call decode on an output registration.')
      end
    end

    class ValidatorNotSpecifiedError < ConfigurationError
      def initialize(inout)
        super("Serializer tried to define an #{inout} without first specifying a validator using either the validator function or unvalidated function. Please call one of those before defining #{inout}s.")
      end
    end

    class ValidatorNotDefinedError < ConfigurationError
      def initialize(identifier, inout)
        super("Serializer tried to define an #{inout} using the media type identifier #{identifier}, but no validation has been set up for that identifier. Please add it to the validator.")
      end
    end

    class UnbackedAliasDefinitionError < ConfigurationError
      def initialize(identifier, inout)
        super(
          "Serializer tried to define an #{inout}_alias that points to the media type identifier #{identifier} but no such #{inout} has been defined yet. Please move the #{inout} definition above the alias.\n\n" +
          "Move the output definition above the alias:\n" +
          "\n" +
          "class MySerializer < MediaTypes::Serialization::Base\n" +
          "#...\n" +
          "output do\n" +
          "  # ...\n" +
          "end\n" +
          "\n" +
          "output_alias 'text/html'\n" +
          "# ^----- move here\n" +
          "end"
        )
      end
    end

    class DuplicateDefinitionError < ConfigurationError
      def initialize(identifier, inout)
        super("Serializer tried to define an #{inout} using the media type identifier #{identifier}, but another #{inout} was already defined with that identifier. Please remove one of the two.")
      end
    end

    class DuplicateUsageError < ConfigurationError
      def initialize(identifier, inout, serializer1, serializer2)
        super("Controller tried to use two #{inout} serializers (#{serializer1}, #{serializer2}) that both have a non-optional #{inout} defined for the media type identifier #{identifier}. Please remove one of the two or filter them more specifically.")
      end
    end

    class UnregisteredMediaTypeUsageError < ConfigurationError
      def initialize(identifier, available)
        super("A serialization or deserialization method was called using a media type identifier '#{identifier}' but no such identifier has been registered yet. Available media types: [#{available.join ', '}]")
      end
    end

    class UnmatchedSerializerError < ConfigurationError
      def initialize(serializer)
        super("Called render_media with a resolved serializer that was not specified in the do block. Please add a 'serializer #{serializer.class.name}, <value>' entry.")
      end
    end

    class VersionsNotAnArrayError < ConfigurationError
      def initialize
        super("Tried to create an input or output with a versions: parameter that is set to something that is not an array. Please use the version: parameter or conver the current value to an array.")
      end
    end
    class ViewsNotAnArrayError < ConfigurationError
      def initialize
        super("Tried to create an input or output with a views: parameter that is set to something that is not an array. Please use the view: parameter or conver the current value to an array.")
      end
    end

    class NoValidatorSetError < ConfigurationError
      def initialize
        super("Unable to return validator as no validator has been set. Either someone tried to fetch the currently defined validator or someone tried to set the validator to 'nil'.")
      end
    end

    class NoSelfLinkProvidedError < ConfigurationError
      def initialize(media_type_identifier)
        super("Tried to render an index of '#{media_type_identifier}' elements but the serializer did not return a :self link for me to use. Please call 'link rel: :self, href: 'https://...' in the #{media_type_identifier} serializer.")
      end
    end

    class MultipleSelfLinksProvidedError < ConfigurationError
      def initialize(media_type_identifier)
        super("Tried to render an index of '#{media_type_identifier}' elements but the serializer returned more than one :self link. Please make sure to only call 'link rel: :self, ...' once in the #{media_type_identifier} serializer.")
      end
    end

    class ArrayInViewParameterError < ConfigurationError
      def initialize(function)
        super("Tried to call #{function} with an array in the view: parameter. Please use the views: parameter instead.")
      end
    end

    class SerializersNotFrozenError < ConfigurationError
      def initialize
        super("Unable to serialize or deserialize objects with unfrozen serializers. Please add 'freeze_io!' to the controller definition.")
      end
    end

    class SerializersAlreadyFrozenError < ConfigurationError
      def initialize
        super("Unable to add a serializer when they are already frozen. Please make sure to call 'freeze_io!' last.")
      end
    end

    class UnableToRefreezeError < ConfigurationError
      def initialize
        super("Freeze was called while the serializers are already frozen. Please make sure to only call 'freeze_io!' once.")
      end
    end

    class NoOutputSerializersDefinedError < ConfigurationError
      def intialize
        super("Called freeze_io! without any allowed output serializers. Users won't be able to make any requests. Please make sure to add at least one allow_output_serializer call to your controller.")
      end
    end

    class AddedEmptyOutputSerializer < ConfigurationError
      def initialize
        super('A serializer was just added to the controller but it contained no output definitions. Usually this is due to using the wrong view parameter when adding it.')
      end
    end
    class AddedEmptyInputSerializer < ConfigurationError
      def initialize
        super('A serializer was just added to the controller but it contained no input definitions. Usually this is due to using the wrong view parameter when adding it.')
      end
    end
  end
end
