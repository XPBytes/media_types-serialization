# frozen_string_literal: true

require 'media_types/serialization/error'

class SerializationRegistration

  def initialize(direction)
    registrations = {}
    self.inout = direction
  end

  attr_accessor :registrations, :inout

  def register_block(serializer, validator, version, block, raw)
    identifier = validator.identifier

    raise DuplicateDefinitionError, identifier, inout if registrations.has_key? identifier
    
    raise ValidatorNotDefinedError, identifier, inout unless raw || validator.validatable?

    registrations[identifier] = SerializationBlockRegistration.new serializer, inout, validator, version, block, raw
  end

  def register_alias(serializer, alias, target_identifier, optional)
    raise DuplicateDefinitionError, identifier, inout if registrations.has_key? identifier
    
    raise UnbackedAliasDefinitionError, target_identifier, inout unless registrations.has_key? target_identifier

    registrations[alias] = SerializationAliasRegistration.new serializer, inout, registrations[target_identifier], optional
  end

  def merge(other)
    raise Error, 'Trying to merge two SerializationRegistration objects with a different direction.' unless inout == other.inout

    result = SerializationRegistration.new(inout)
    
    prev_keys = Set.new(registrations.keys)
    new_keys = Set.new(other.registrations.keys)
    overlap = prev_keys & new_keys

    result.registrations = registrations.merge(other.registrations)
    overlap.each do |identifier|
      prev_item = registrations[identifier]
      new_item = other.registrations[identifier]
      merge_result = prev_item.merge(new_item)

      raise DuplicateUsageError(identifier, inout, prev_item.serializer, new_item.serializer) if merge_result.nil?

      result.registrations[identifier] = merge_result
    end

    result
  end

  def call(victim, media_type, context)
    registration = registrations[identifier]
    raise UnregisteredMediaTypeUsage, victim if registration.nil?

    registration.call(victim, context)
  end
end

class SerializationBaseRegistration

  def initialize(serializer, inout, validator)
    self.serializer = serializer
    self.inout = inout
    self.validator = validator
  end

  def merge(other)
    nil
  end

  def call(victim, context)
    raise "Assertion failed, call function called on base registration."
  end

  attr_accessor :serializer, :inout, :validator
end

class SerializationBlockRegistration < SerializationBaseRegistration

  def initialize(serializer, inout, validator, version, block, raw)
    self.version = version
    self.block = block
    self.raw = raw
    super(serializer, inout, validator)
  end

  def call(victim, context)
    # TODO: un-JSON if not raw and input
    # TODO: validate input if input and not raw
    
    result = block.call(victim, self.version, context)

    # TODO: validate output if output and not raw
    result
  end

  attr_accessor :version, :block, :raw
end

class SerializationAliasRegistration < SerializationBaseRegistration
  
  def initialize(serializer, inout, validator, target, optional)
    self.target = target
    self.optional = optional
    super(serializer, inout, validator)
  end

  def merge(other)
    return nil unless other.is_a?(SerializationAliasRegistration)

    if !optional
      return nil unless other.optional # two non-optional can't merge
      return self
    end

    return other # if both optional, or other is !optional, newer one wins.
  end

  def call(victim, context)
    self.target.call(victim, context)
  end

  attr_accessor :target, :optional
end

