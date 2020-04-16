# MediaTypes::Serialization

[![Build Status: master](https://travis-ci.com/XPBytes/media_types-serialization.svg)](https://travis-ci.com/XPBytes/media_types-serialization)
[![Gem Version](https://badge.fury.io/rb/media_types-serialization.svg)](https://badge.fury.io/rb/media_types-serialization)
[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)

`respond_to` on steroids. Add versioned serialization and deserialization to your Rails projects.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'media_types-serialization'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install media_types-serialization

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

BookSerializer.serialize(book, 'vnd.acme.book.v1+json', context: nil)
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

class BookController < ActionController::API
  include MediaTypes::Serialization

  allow_output_serializer(BookSerializer, only: %i[show])
  freeze_io!
      
  def show 
    book = Book.new
    book.title = 'Everything, abridged'

    render_media book
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
      link :self, href: context.book_url(obj) if version >= 3

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
      link :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end

  output view: :index, version: 3 do |arr, version, context|
    attribute :books do
      link :self, href: context.book_index_url
      
      index arr, version: version
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
      link :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end

  output view: :index, version: 3 do |arr, version, context|
    attribute :books do
      link :self, href: context.book_index_url
      
      index arr, version: version
    end
  end
  
  output view: :collection, version: 3 do |arr, version, context|
    attribute :books do
      link :self, href: context.book_collection_url
      
      collection arr, version: version
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
      link :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end

  input version: 3
end

class BookController < ActionController::API
  include MediaTypes::Serialization

  allow_output_serializer(BookSerializer, only: %i[show])
  allow_input_serializer(BookSerializer, only: %i[create])
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
      link :self, href: context.book_url(obj) if version >= 3

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

  allow_output_serializer(BookSerializer, only: %i[show])
  allow_input_serializer(BookSerializer, only: %i[create])
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
      
      link :self, href: context.book_url(obj)
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

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end
  output_alias 'application/json' # maps application/json to to applicaton/vnd.acme.book.v1+json

  input view: :create, versions: [1, 2, 3] do |json, version, context|
    book = Book.new
    book.title = json['book']['title']
    book.description = 'Not available'
    book.description = json['book']['description'] if version >= 2

    # Make sure not to save here but only save in the controller
    book
  end
  input_alias 'application/json', view: :create # maps application/json to to applicaton/vnd.acme.book.v1+json
```

Validation will be done using the remapped validator. Aliasses map to version `nil` if that is available or `1` otherwise. It is not possible to configure this version.

### HTML

This library has a built in API viewer. The viewer can be accessed by by appending a `?api_viewer=last` query parameter to the URL.

To enable the API viewer, use: `allow_api_viewer` in the controller.

```ruby
class BookController < ActionController::API
  include MediaTypes::Serialization

  allow_api_viewer
  
  allow_output_serializer(MediaTypes::ApiViewer)

  allow_output_serializer(BookSerializer, only: %i[show])
  allow_input_serializer(BookSerializer, only: %i[create])
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

You can also output custom HTML:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator

  output versions: [1, 2, 3] do |obj, version, context|
    attribute :book do
      link :self, href: context.book_url(obj) if version >= 3

      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end
  
  output_raw view: :html do |obj, context|
    render_view 'book/show', context: context, assigns: {
      title: obj.title,
      description: obj.description
    }
  end
  
  output_alias 'text/html', view: :html
end
```

#### Errors

This library adds support for returning errors to clients using the [`application/problem+json`](https://tools.ietf.org/html/rfc7231) media type. You can catch and transform application errors by adding an `output_error` call before `freeze_io!`:

```ruby
class BookController < ActionController::API
  include MediaTypes::Serialization

  output_error CanCan::AccessDenied do |p, error|
    p.title 'You do not have enough permissions to perform this action.', lang: 'en'
    p.title 'Je hebt geen toestemming om deze actie uit te voeren.', lang: 'nl-NL'

    p.status_code :forbidden
  end

  freeze_io!

  # ...   
end
```

The exception you specified will be rescued by the controller and will be displayed to the user along with a link to the shared wiki page for that error type. Feel free to add instructions there on how clients should solve this problem. You can find more information at: http://docs.delftsolutions.nl/wiki/Error
If you want to override this url you can use the `p.url(href)` function.

By default the `message` property of the error is used to fill the `details` field. You can override this by using the `p.override_details(description, lang:)` function.

Custom attributes can be added using the `p.attribute(name, value)` function.

### Related

- [`MediaTypes`](https://github.com/SleeplessByte/media-types-ruby): :gem: Library to create media type validators.

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

Has the same behavior as `output_alias` but can be used by multiple serializers. The serializer that is loaded last in the controller 'wins' control over this media type identifier. If any of the serializers have an `output_alias` defined with the same media type identifier that one will win instead.

#### `input( view:, version:, versions: ) do |obj, version, context|`

Defines a deserialization block. Either version or versions can be set. View should be a symbol or unset.

Obj is the object to be serialized, version is the negotiated version and context is the context passed in from the serialize function. When using the controller integration, context is the current controller.

The block should return the internal representation of the object. Best practise is to make sure not to change state in this function but to leave that up to the controller.

#### `input_raw( view:, version:, versions: ) do |bytes, version, context|`

This has the same behavior as `input` but takes in raw data. Input is not validated.

#### `input_alias( media_type_identifier, view: )`

Defines a legacy mapping. This will make the serializer parse the media type `media_type_identifier` as if it was version 1 of the specified view. If view is undefined it will use the input serializer without a view defined.

#### `input_alias_optional( media_type_identifier, view: )`

Has the same behavior as `input_alias` but can be used by multiple serializers. The serializer that is loaded last in the controller 'wins' control over this media type identifier. If any of the serializers have an `input_alias` defined with the same media type identifier that one will win instead.

#### `disable_wildcards`

Disables registering wildcard media types.

### Serializer definition

The following methods are available within an `output ... do` block.

#### `attribute( key, value = {} ) do`

Sets a value for the given key. If a block is given, any `attribute`, `link`, `collection` and `index` statements are run in context of `value`.

Returns the built up context so far.

#### `link( rel, href:, emit_header: true, **attributes )`

Adds a `_link` block to the current context. Also adds the specified link to the HTTP Link header. `attributes` allows passing in custom attributes.

If `emit_header` is `true` the link will also be emitted as a http header.

Returns the built up context so far.

#### `index( array, serializer, version:, view: nil )`

Adds an `_index` block to the current context. Uses the self links of the specified view to construct an index of urls to the child objects.

Returns the built up context so far.

#### `collection( array, serializer, version:, view: nil )`

Adds an `_embedded` block to the current context. Uses the specified serializer to embed the child objects.
Optionally a block can be used to modify the output from the child serializer.

Returns the built up context so far.

#### `hidden do`

Sometimes you want to add links without actually modifying the object. Calls to `attribute`, `link`, `index`, `collection` made inside this block won't modify the context. Any calls to link will only set the HTTP Link header.

Returns the unmodified context.

#### `emit`

Can be added to the end of a block to fix up the return value to return the built up context so far.

Returns the built up context so far.

#### `object do`

Runs a block in a new context and returns the result

#### `render_view( view, context:, **args)`

Can be used to render a view. You can set local variables in the view by assigning a hash to the `assigns:` parameter.

### Controller definition

These functions are available during the controller definition if you add `include MediaTypes::Serialization`.

#### `allow_output_serializer( serializer, views: nil, **filters )`

Configure the controller to allow the client to request responses emitted by the specified serializer. Optionally allows you to specify which views to allow by passing an array in the views parameter.

Accepts the same filters as `before_action`.

#### `allow_input_serializer( serializer, views: nil, **filters )`

Configure the controller to allow the client to send bodies with a `Content-Type` that can be deserialized using the specified serializer. Optionally allows you to specify which views to allow by passing an array in the views parameter.

Accepts the same filters as `before_action`.

#### `allow_all_input( **filters )`

Disables input deserialization. Running `deserialize` while allowing all input will result in an error being thrown.

#### `not_acceptable_serializer( serializer )`

Replaces the serializer used to render the error page when no media type could be negotiated using the `Accept` header.

#### `unsupported_media_type_serializer( serializer )`

Adds a serializer that can be used to render the error page when the client submits a body with a `Content-Type` that was not added to the whitelist using `allow_input_serialization`.

#### `clear_unsupported_media_type_serializers!`

Clears the list of serializers used to render the error when the client supplies non-valid input.

#### `input_validation_failed_serializer( serializer )`

Adds a serializer that can be used to render the error page when input validation fails.

#### `clear_input_validation_failed_serializers!`

Clears the list of serializers used to render the error when the client supplies non-valid input.

#### `allow_api_viewer(serializer: MediaTypes::Serialization::Serializers::ApiViewer, **filter_opts)`

Enables rendering the api viewer when adding the `api_viewer=last` query parameter to the url.

#### `freeze_io!`

Registers serialization and deserialization in the controller. This function must be called before using the controller.

### Controller usage

These functions are available during method execution in the controller.

#### `render_media( obj, serializers: nil, not_acceptable_serializer: nil, **options ) do`

Serializes an object and renders it using the appropriate content type. Options are passed through to the controller `render` function. Allows you to specify different objects to different serializers using a block:

```ruby
render_media do
  serializer BookSerializer, book
  serializer BooksSerializer do
    [ book ]
  end
end
```

Warning: this block can be called multiple times when used together with recursive serializers like the API viewer. Try to avoid changing state in this block.

If you want to render with different serializers than defined in the controller you can pass an array of serializers in the `serializers` property.

If you want to override the serializer that is used to render the response when no acceptable Content-Type could be negotiated you can pass the desired serializer in the `not_acceptable_serializer` property.

This method throws a `MediaTypes::Serialization::OutputValidationFailedError` error if the output does not conform to the format defined by the configured validator. Best practise is to return a 500 error to the client.

If no acceptable Content-Type could be negotiated the response will be rendered using the serialized defined by the class `not_acceptable_serializer` function or by the `not_acceptable_serializer` property.

Due to the way this gem is implemented it is not possible to use instance variables (`@variable`) in the `render_media` do block.

#### `deserialize( request )`

Deserializes the request body using the configured input serializers and returns the deserialized object.

Returns nil if no input body was given by the client.

This method throws a `MediaTypes::Serialization::InputValidationFailedError` error if the incoming data does not conform to the specified schema.

#### `deserialize!( request )`

Does the same as `deserialize( request )` but gives the client an error page if no input was supplied.

#### `resolve_serializer(request, identifier = nil, registration = @serialization_output_registration)`

Returns the serializer class that will handle the given request.

## Customization
The easiest way to customize the look and feel of the built in pages is to provide your own logo and background in an initializer:

```ruby
# config/initializers/serialization.rb

MediaTypes::Serialization::Serializers::CommonCSS.background = 'linear-gradient(245deg, #3a2f28 0%, #201a16 100%)'
MediaTypes::Serialization::Serializers::CommonCSS.logo_width = 12
MediaTypes::Serialization::Serializers::CommonCSS.logo_data = <<-HERE
<svg height="150" width="500">
  <ellipse cx="240" cy="100" rx="220" ry="30" style="fill:purple" />
  <ellipse cx="220" cy="70" rx="190" ry="20" style="fill:lime" />
  <ellipse cx="210" cy="45" rx="170" ry="15" style="fill:yellow" />
</svg>
HERE
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [XPBytes/media_types-serialization](https://github.com/XPBytes/media_types-serialization).
