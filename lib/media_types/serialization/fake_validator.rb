
class FakeValidator
  def initialize(prefix, view = nil, version = nil, suffixes = {})
    self.prefix = prefix
    self.suffixes = suffixes
    self.internal_view = view
    self.internal_version = version
  end

  def view(view)
    FakeValidator.new(self.prefix, view, self.internal_version, self.suffixes)
  end

  def version(version)
    FakeValidator.new(self.prefix, self.internal_view, version, self.suffixes)
  end

  def override_suffix(suffix)
    suffixes[[internal_view,internal_version]] = suffix
  end

  def identifier
    suffix = suffixes[[internal_view,internal_version]] || ''
    result = prefix
    result += '.' + internal_view.to_s unless internal_view.nil?
    result += '.v' + internal_version.to_s unless internal_version.nil?
    result += '+' + suffix.to_s unless suffix.nil?

    result
  end

  def validatable?
    true
  end

  attr_accessor :prefix
  attr_accessor :suffixes

  protected

  attr_accessor :internal_view
  attr_accessor :internal_version

end
