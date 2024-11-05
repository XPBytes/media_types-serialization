
# Validator that accepts all input
class FakeValidator
  def initialize(prefix, view = nil, version = nil, suffixes = {})
    self.prefix = prefix
    self.suffixes = suffixes
    self.internal_view = view
    self.internal_version = version
  end

  UNSET = Object.new

  def view(view = UNSET)
    return self.internal_view if view == UNSET
    FakeValidator.new(prefix, view, internal_version, suffixes)
  end

  def version(version = UNSET)
    return self.internal_version if version == UNSET
    FakeValidator.new(prefix, internal_view, version, suffixes)
  end

  def override_suffix(suffix)
    suffixes[[internal_view, internal_version]] = suffix
    FakeValidator.new(prefix, internal_view, version, suffixes)
  end

  def identifier
    suffix = suffixes[[internal_view, internal_version]] || ''
    result = prefix
    result += '.v' + internal_version.to_s unless internal_version.nil?
    result += '.' + internal_view.to_s unless internal_view.nil?
    result += '+' + suffix.to_s unless suffix.empty?

    result
  end

  def validatable?
    true
  end

  def validate!(*)
    true
  end

  attr_accessor :prefix
  attr_accessor :suffixes

  protected

  attr_accessor :internal_view
  attr_accessor :internal_version
end
