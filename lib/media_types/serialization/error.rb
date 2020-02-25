
module MediaTypes
  module Serialization
    class Error < StandardError
    end

    class ConfigurationError < Error
    end

    class SerializationNotInitializedError < ConfigurationError
      def initialize(msg='Controller did not call freeze_io!')
        super
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
        super("Serializer tried to define an #{inout}_alias that points to the media type identifier #{identifier} but no such #{inout} has been defined yet. Please move the #{inout} definition above the alias.")
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
  end
end
