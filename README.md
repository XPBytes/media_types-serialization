# MediaTypes::Serialization

[![Build Status: master](https://travis-ci.com/XPBytes/media_types-serialization.svg)](https://travis-ci.com/XPBytes/media_types-serialization)
[![Gem Version](https://badge.fury.io/rb/media_types-serialization.svg)](https://badge.fury.io/rb/media_types-serialization)
[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)

`respond_to` on steroids. Add versioned serialization and deserialization to your rails projects.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'media_types-serialization'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install media_types-serialization
    
If you have not done this before, and you're using `rails`, install the necessary parts using:

```bash
rails g media_types:serialization:api_viewer
```

This will:

- Add the default `html_wrapper` layout which is an API Viewer used as fallback or the `.api_viewer` format
- Add the default `template_controller` which allows the API Viewer to post templated links
- Add the `route` for these templated link forms
- Add an initializer that registers the `media` renderer and `api_viewer` media type

## Usage

Serializers help you in converting a ruby object to a representation matching a specified [Media Type validator](https://github.com/SleeplessByte/media-types-ruby) and the other way around.

### Creating a serializer

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  unvalidated 'application/vnd.acme.book'

  # outputs with a Content-Type of application/vnd.acme.book.v1+json
  output version: 1 do |obj, version, context|
    {
      book: {
        title: obj.title
      }
    }
  end
end
```

To convert a ruby object to a json representation:

```ruby
class Book
  attr_accessor :title
end

book = Book.new
book.title = 'Everything, abridged'

BookSerializer.serialize(book, BookValidator.version(1), context: nil)
# => { "book": { "title": "Everything, abridged" } }
```

### Validations

Right now the serializer does not validate incoming or outgoing information. This can cause issues when you accidentally emit non-conforming data that people start to depend on. To make sure you don't do that you can specify a [Media Type validator](https://github.com/SleeplessByte/media-types-ruby):

```ruby
require 'media_types'

class BookValidator
  include MediaTypes::Dsl

  def self.organisation
    'acme'
  end

  use_name 'book'

  validations do
    version 1 do
      attribute :book do
        attribute :title, String
      end
    end
  end
end

class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  # outputs with a Content-Type of application/vnd.acme.book.v1+json
  output version: 1 do |obj, version, context|
    {
      book: {
        title: obj.title
      }
    }
  end
end
```

For more information, see the [Media Types docs](https://github.com/SleeplessByte/media-types-ruby).

### Controller integration

You can integrate the serialization system in rails, giving you automatic [Content-Type negotiation](https://en.wikipedia.org/wiki/Content_negotiation) using the `Accept` header:

```ruby
require 'media_types/serialization'
require 'media_types/serialization/renderer/register'

class BookController < ActionController::API
  include MediaTypes::Serialization

  allow_output_serialization(BookSerializer, only: %i[show])
  freeze_io!
      
  def show 
    book = Book.new
    book.title = 'Everything, abridged'

    render media: serialize_media(book), content_type: request.format.to_s
  end
end
```

While using the controller integration the context will always be set to the current controller. This allows you to construct urls.

### Versioning

To help with supporting older versions, serializers have a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) to construct json objects:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2] do |obj, version, context|
    attribute :book do
      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end
end
```

```ruby
BookSerializer.serialize(book, BookValidator.version(1), context: nil)
# => { "book": { "title": "Everything, abridged" } }

BookSerializer.serialize(book, BookValidator.version(2), context: nil)
# => { "book": { "title": "Everything, abridged", "description": "Mu" } }
```

### Links

When making [HATEOAS](https://en.wikipedia.org/wiki/HATEOAS) compliant applications it's very useful to include `Link` headers in your response so clients can use a `HEAD` request instead of having to fetch the entire resource. Serializers have convenience methods to help with this:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end
end
```

This returns the following response:

```ruby
BookSerializer.serialize(book, BookValidator.version(3), context: controller)
# header = Link: <https://example.org/>; rel="self"
# => {
#      "book": {
#        "_links": {
#          "self": { "href": "https://example.org" }
#        },
#        "title": "Everything, abridged",
#        "description": "Mu"
#      }
#    }
```

### Collections

There are convenience methods for serializing arrays of objects based on a template.

#### Indexes

An index is a collection of urls that point to members of the array. The index method automatically generates it based on the self links defined in the default view of the same version.

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end

  output view: :index, version: 3 do |arr, version, context|
    attribute :books do
      link rel: :self, href: context.book_index_url
      
      index arr 
    end
  end
end
```

```ruby
BookSerializer.serialize([book], BookValidator.view(:index).version(3), context: controller)
# header = Link: <https://example.org/index>; rel="self"
# => {
#      "books": {
#        "_links": {
#          "self": { "href": "https://example.org" }
#        },
#        "_index": [
#          { "href": "https://example.org" }
#        ]
#      }
#    }
```

#### Collections

A collection inlines the member objects. The collection method automatically generates it based on the default view of the same version.

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end

  output view: :index, version: 3 do |arr, version, context|
    attribute :books do
      link rel: :self, href: context.book_index_url
      
      index arr 
    end
  end
  
  output view: :collection, version: 3 do |arr, version, context|
    attribute :books do
      link rel: :self, href: context.book_collection_url
      
      collection arr 
    end
  end
end
```

```ruby
BookSerializer.serialize([book], BookValidator.view(:collection).version(3), context: controller)
# header = Link: <https://example.org/collection>; rel="self"
# => {
#      "books": {
#        "_links": {
#          "self": { "href": "https://example.org" }
#        },
#        "_embedded": [
#          {
#            "_links": {
#              "self": { "href": "https://example.org" }
#            },
#            "title": "Everything, abridged",
#            "description": "Mu"
#          }
#        ]
#      }
#    }
```

### Input deserialization

You can mark a media type as something that's allowed to be sent along with a PUT request as follows:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end

  input version: 3
end

class BookController < ActionController::API
  include MediaTypes::Serialization

  allow_output_serialization(BookSerializer, only: %i[show])
  allow_input_serialization(BookSerializer, only: %i[create])
  freeze_io!
      
  def show 
    book = Book.new
    book.title = 'Everything, abridged'

    render media: serialize_media(book), content_type: request.format.to_s
  end

  def create
    json = deserialize(request, context: self) # does validation for us
    puts json
  end
end
```

If you use [ActiveRecord](https://guides.rubyonrails.org/active_record_basics.html) you might want to convert the verified json data during deserialization:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end

  input versions: [1, 2, 3] do |json, version, context|
    book = Book.new
    book.title = json['book']['title']
    book.description = 'Not available'
    book.description = json['book']['description'] if version >= 2

    # Best practise is to only save in the controller.
    book
  end
end

class BookController < ActionController::API
  include MediaTypes::Serialization

  allow_output_serialization(BookSerializer, only: %i[show])
  allow_input_serialization(BookSerializer, only: %i[create])
  freeze_io!
      
  def show 
    book = Book.new
    book.title = 'Everything, abridged'

    render media: serialize_media(book), content_type: request.format.to_s
  end

  def create
    book = deserialize(request, context: self)
    book.save!

    render media: serialize_media(book), content_type request.format.to_s
  end
end
```

If you don't want to apply any input validation or deserialization you can use the `allow_all_input` method instead of `allow_input_serialization`.

### Raw output

Sometimes you need to output raw data. This cannot be validated. You do this as follows:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output_raw view: :raw, version: 3 do |obj, version, context|
    hidden do
      # Make sure links are only set in the headers, not in the body.
      
      link rel: :self, href: context.book_url(obj)
    end

    "I'm a non-json output"
  end
end
```

### Raw input

You can do the same with input:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  input_raw view: raw, version: 3 do |bytes, version, context|
    book = Book.new
    book.description = bytes

    book
  end
end
```

### Remapping media type identifiers

Sometimes you already have old clients using an `application/json` media type identifier when they do requests. While this is not a good practise as this makes it hard to add new fields or remove old ones, this library has support for migrating away:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  alias_output 'application/json' # maps application/json to to applicaton/vnd.acme.book.v1+json
  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end

  alias_input 'application/json', view: :create # maps application/json to to applicaton/vnd.acme.book.v1+json
  input view: :create, versions: [1, 2, 3] do |json, version, context|
    book = Book.new
    book.title = json['book']['title']
    book.description = 'Not available'
    book.description = json['book']['description'] if version >= 2

    # Make sure not to save here but only save in the controller
    book
  end
```

Validation will be done using the remapped validator. It is not possible to map media type identifiers to versions higher than version 1.

### HTML

This library has a built in API viewer. The viewer can be accessed by sending an `Accept: application/vnd.xpbytes.api-viewer.v1` header or by appending an `.api_viewer` extension to the URL.

You can optionally configure the serializer to output the api viwer when the client requests the `text/html` media type:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end
  
  output_html
end
```
You can change the default `api_viewer` template by setting:

```ruby
::MediaTypes::Serialization.api_viewer_layout = '/path/to/wrapper/layout'
```

You can also output custom HTML:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link rel: :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end
  
  output_html do |obj, context|
    '<html><head><title>Hello World</title></head><body>hi</body></html>'   
  end
end
```

### Related

- [`MediaTypes`](https://github.com/SleeplessByte/media-types-ruby): :gem: Library to create media type definitions, schemes and validations
- [`MediaTypes::Deserialization`](https://github.com/XPBytes/media_types-deserialization): :cyclone: Add media types supported deserialization using your favourite parser, and media type validation.
- [`MediaTypes::Validation`](https://github.com/XPBytes/media_types-validation): :heavy_exclamation_mark: Response validations according to a media-type

## API

### Serializer definition

These methods become available during class definition if you inherit from `MediaTypes::Serialization::Base`.

#### `unvalidated( prefix )`

Disabled validation for this serializer. Prefix is of the form `application/vnd.<organisation>.<name>`.

Either unvalidated or validator must be used while defining a serializer.

#### `validator( media_type_validator )`

Enabled validation for this serializer using a [Media Type Validator](https://github.com/SleeplessByte/media-types-ruby).

Either validator or unvalidated must be used while defining a serializer.

#### `output( view:, version:, versions: ) do |obj, version, context|`

Defines a serialization block. Either version or versions can be set. View should be a symbol or unset.

Obj is the object to be serialized, version is the negotiated version and context is the context passed in from the serialize function. When using the controller integration, context is the current controller.

The block should return an object to convert into JSON.

#### `output_raw( view:, version:, versions: ) do |obj, version, context|`

This has the same behavior as `output` but should return a string instead of an object. Output is not validated.

#### `output_alias( media_type_identifier, view: )`

Defines a legacy mapping. This will make the deserializer parse the media type `media_type_identifier` as if it was version 1 of the specified view. If view is undefined it will use the output serializer without a view defined.

#### `output_alias_optional( media_type_identifier, view: )`

Has the same behavior as `output_alias` but can be used by multiple serializers. The serializer that is loaded first in the controller 'wins' control over this media type identifier. If any of the serializers have an `output_alias` defined with the same media type identifier that one will win instead.

#### `input( view:, version:, versions: ) do |obj, version, context|`

Defines a deserialization block. Either version or versions can be set. View should be a symbol or unset.

Obj is the object to be serialized, version is the negotiated version and context is the context passed in from the serialize function. When using the controller integration, context is the current controller.

The block should return the internal representation of the object. Best practise is to make sure not to change state in this function but to leave that up to the controller.

#### `input_raw( view:, version:, versions: ) do |bytes, version, context|`

This has the same behavior as `input` but takes in raw data. Input is not validated.

#### `input_alias( media_type_identifier, view: )`

Defines a legacy mapping. This will make the serializer parse the media type `media_type_identifier` as if it was version 1 of the specified view. If view is undefined it will use the input serializer without a view defined.

#### `input_alias_optional( media_type_identifier, view: )`

Has the same behavior as `input_alias` but can be used by multiple serializers. The serializer that is loaded first in the controller 'wins' control over this media type identifier. If any of the serializers have an `input_alias` defined with the same media type identifier that one will win instead.

### Serializer definition

The following methods are available within an `output ... do` block.

#### `attribute( key, value = {} ) do`

Sets a value for the given key. If a block is given, any `attribute`, `link`, `collection` and `index` statements are run in context of `value`.

Returns the built up context so far.

#### `link( rel:, href: )`

Adds a `_link` block to the current context. Also adds the specified link to the HTTP Link header.

Returns the built up context so far.

#### `index( array, view: nil )`

Adds an `_index` block to the current context. Uses the self links of the specified view to construct an index of urls to the child objects.

Returns the built up context so far.

#### `collection( array, view: nil )`

Adds an `_embedded` block to the current context. Uses the specified serializer to embed the child objects.

Returns the built up context so far.

#### `hidden do`

Sometimes you want to add links without actually modifying the object. Calls to `attribute`, `link`, `index`, `collection` made inside this block won't modify the context. Any calls to link will only set the HTTP Link header.

Returns the unmodified context.

### Controller definition

These functions are available during the controller definition if you add `include MediaTypes::Serialization`.

#### `allow_output_serialization( serializer, **filters )`

TODO: need a way to either explicitly only use the default view or a way to use all views.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [XPBytes/media_types-serialization](https://github.com/XPBytes/media_types-serialization).
