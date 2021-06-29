=begin
The MIT License (MIT)

Copyright (c) 2019 Derk-Jan Karrenbeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
=end

require 'media_types/serialization/utils/header_list'

module MediaTypes
  module Serialization
    module Utils
      class AcceptHeader < DelegateClass(Array)
        def initialize(value)
          __setobj__ HeaderList.new(value, entry_klazz: AcceptHeader::Entry)
        end

        class Entry
          def initialize(media_type, index:, parameters:)
            self.media_type = media_type
            self.parameters = parameters
            self.index = index

            freeze
          end

          attr_reader :media_type

          # noinspection RubyInstanceMethodNamingConvention
          def q
            parameters.fetch(:q) { 1.0 }.to_f
          end

          def <=>(other)
            quality = other.q <=> q
            return quality unless quality.zero?
            index <=> other.send(:index)
          end

          def [](parameter)
            parameters.fetch(String(parameter).to_sym)
          end

          def to_header
            to_s
          end

          def to_s
            [media_type].concat(parameters.map { |k, v| "#{k}=#{v}" }).compact.reject(&:empty?).join('; ')
          end

          private

          attr_writer :media_type
          attr_accessor :parameters, :index
        end
      end
    end
  end
end
