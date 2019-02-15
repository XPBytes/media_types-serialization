require 'test_helper'

class MediaTypes::SerializationTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::MediaTypes::Serialization::VERSION
  end
end
