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

module MediaTypes
  module Serialization
    module Utils
      ##
      # @example Accept values
      #
      #   class AcceptHeader < DelegateClass(Array)
      #     def initialize(value)
      #       super MediaTypes::Serialization::Utils::HeaderList.new(value, entry_klazz: AcceptHeader::Entry)
      #     end
      #
      #     class Entry
      #       def initialize(media_type, index: parameters:)
      #         ...
      #       end
      #
      #       def q
      #         parameters.fetch(:q) { 1.0 }.to_f
      #       end
      #
      #       def <=>(other)
      #         quality = other.q <=> q
      #         return quality unless quality.zero?
      #         index <=> other.index
      #       end
      #     end
      #   end
      #
      #   Accept.new(['*/*; q=0.1', 'application/json, text/html; q=0.8'])
      #   # => List['application/json', 'text/html', '*/*']
      #
      module HeaderList
        HEADER_DELIMITER    = ','
        PARAMETER_DELIMITER = ';'

        module_function

        def parse(combined, entry_klazz:)
          Array(combined).map { |line| line.split(HEADER_DELIMITER) }.flatten.each_with_index.map do |entry, index|
            value, *parameters = entry.strip.split(PARAMETER_DELIMITER)
            indexed_parameters = ::Hash[Array(parameters).map { |p| p.strip.split('=') }].transform_keys!(&:to_sym)
            entry_klazz.new(value, index: index, parameters: indexed_parameters)
          end
        end

        def new(combined, entry_klazz:)
          result = parse(combined, entry_klazz: entry_klazz)
          entry_klazz.instance_methods(false).include?(:<=>) ? result.sort! : result
        end

        def to_header(list)
          # noinspection RubyBlockToMethodReference
          list.map { |entry| stringify_entry(entry) }
              .join("#{HEADER_DELIMITER} ")
        end

        def stringify_entry(entry)
          return entry.to_header if entry.respond_to?(:to_header)
          return entry.to_s if entry.respond_to?(:to_s)
          entry.inspect
        end
      end
    end
  end
end
