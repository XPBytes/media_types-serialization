
module MediaTypes
  module Serialization
    class Error < StandardError
    end

    class NoInputSerializerError < Error
    end
  end
end
