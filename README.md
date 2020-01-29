# MediaTypes::Serialization

[![Build Status: master](https://travis-ci.com/XPBytes/media_types-serialization.svg)](https://travis-ci.com/XPBytes/media_types-serialization)
[![Gem Version](https://badge.fury.io/rb/media_types-serialization.svg)](https://badge.fury.io/rb/media_types-serialization)
[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)

Add versioned serialization and deserialization to your rails projects.

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

Make sure you have defined a validator using the [media-types](https://github.com/SleeplessByte/media-types-ruby) gem. You can then craete a serializer for it as follows:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator # BookValidator is a media type validator.

  # outputs with a content-type of application/vnd.acme.book.v1+json
  output version: 1, do |obj, version, context|
    {
      book: {
        title: obj.title
      }
    }
  end
end
```

To convert a ruby object to a validated json representation:

```ruby
class Book
  attr_accessor :title
end

book = Book.new
book.title = 'Everything, abridged'

BookSerializer.serialize(book, BookValidator.version(1), nil)
# => { "book": { "title": "Everything, abridged" } }
```

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

### Versioning

To help with supporting older versions, serializers have a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) to construct json objects:

```ruby
class BookSerializer < MediaTypes::Serialization::Base
  validator BookValidator # BookValidator is a media type validator.

  # outputs with a content-type of application/vnd.acme.book.v1+json
  output versions: [1, 2], do |obj, version, context|
    attribute :book do
      attribute :title, obj.title
      attribute :description, obj.description if version >= 2
    end
  end
end
```

```ruby
BookSerializer.serialize(book, BookValidator.version(1), nil)
# => { "book": { "title": "Everything, abridged" } }

BookSerializer.serialize(book, BookValidator.version(2), nil)
# => { "book": { "title": "Everything, abridged", "description": "Mu" } }
```

--- old

### Serializer

Add a serializer that can serialize a certain media type. The `to_hash` function will be called _explicitly_ in your
controller, so you can always use your own, favourite serializer here to do the hefty work. This gem does provide some
easy tools, usually enough to do most serialization.
  
```ruby
class Book < ApplicationRecord
  class Serializer < MediaTypes::Serialization::Base
    serializes_media_type MyNamespace::MediaTypes::Book
    
    def fields
      if current_media_type.create?
        return %i[name author]
      end
    
     %i[name author updated_at views]
    end

    def to_hash
      extract(serializable, fields).tap do |result|
        result[:_links] = extract_links unless current_media_type.create?
      end
    end

    alias to_h to_hash
    
    protected
    
    def extract_self
      # A serializer gets the controller as context
      { href: context.api_book_url(serializable) }
    end

    def extract_links
      { 
        'self': extract_self,
        'signatures': { href: context.api_book_signatures_url(serializable) }
      }
    end
  end
end
```
By default, The passed in `MediaType` gets converted into a constructable (via `to_constructable`) and invoked with the
current `view` (e.g. `create`, `index`, `collection` or ` `). This means that by default it will be able to serialize 
the latest version you `MediaType` is reporting. The best way to supply your media type is via the [`media_types`](https://github.com/SleeplessByte/media-types-ruby) gem.

#### Multiple suffixes, one serializer

By default, the media renderer will automatically detect and inject the following:
- suffix `+json` if you define `to_json`
- suffix `+xml` if you define `to_xml`
- type `text/html` if you define `to_html`

If you do _not_ define these methods, only the `default` suffix / type will be used, `accepts_html` for the `text/html` 
content-type.

If you don't define `to_html`, but try to make a serializer output `html`, it will be rendered in the layout at: 
`serializers/wrapper/html_wrapper.html.erb` (or any other templating extension).

#### Migrations (versions)

If the serializer can serialize multiple _versions_, you can supply them through `additional_versions: [2, 3]`. A way to
handle this is via backward migrations, meaning you'll migrate from the current version back to an older version.

```ruby
class Book < ApplicationRecord
  class BasicSerializer < MediaTypes::Serialization::Base
  
    # Maybe it's currently at version 2, so tell the base that this also serializes version 1
    # You can also use a range to_a: (1...4).to_a
    # 
    serializes_media_type MyNamespace::MediaTypes::Book, additional_versions: [1]
    
    def to_hash
      # This enables migrations right when it's being serialized
      # 
      migrate do
        extract(serializable, fields).tap do |result|
          result[:_links] = extract_links unless current_media_type.create?
        end
      end
    end
  
    # This defines migrations. You can use classes, commands or anything else to execute this code
    # but inline migrations work fine if you don't have a lot of them. 
    backward_migrations do
    
      # This is called if the version requested is 1 _or_ lower. This means you can compose your migrations. The 
      # migrations with a _lower_ version than the requested version are NOT executed.
      version 1 do |result|
        result.tap do |r|
          if r.key?(:views)
            r[:views_count] = r.delete(:views)
          end
        end
      end
    end
  end
end
```

### Controller

In your base controller, or wherever you'd like, include the `MediaTypes::Serialization` concern. In the controller that
uses the serialization, you need to explicitly `accept` it if you want to use the built-in lookups.

```ruby
require 'media_types/serialization'
require 'media_types/serialization/renderer/register'

class ApiController < ActionController::API
  include MediaTypes::Serialization
end

class BookController < ApiController

  allow_output_serialization(Book::BasicSerializer, accept_html: false, only: %i[show])
  allow_output_html(Book::CoverHtmlSerializer, only: %i[show])
  freeze_io!
      
  def show 
    # If you do NOT pass in the content_type, it will re-use the current content_type of the response if set or
    # use the default content type of the serializer. This is fine if you only output one Content-Type in the
    # action, but not if you are relying on content-negotiation. 
    
    render media: serialize_media(@book), content_type: request.format.to_s
  end
end
```

If you have normalized your resources (e.g. into `@resource`), you can add a `render_media` method to your
`BaseController` and render resources like so:

```ruby
class ApiController < ActionController::API
  def render_media(**opts)
    render media: serialize_media(@resource), content_type: request.format.to_s, **opts
  end
end
```

And then call `render_media` whenever you're ready to render.

#### Input

If you want clients to be able to send data to the server in their POST or PUT requests, you can whitelist media types.

```ruby
class BookController < ApiController

  allow_output_serialization(Book::BasicSerializer, accept_html: true, only: %i[show])
  allow_input_serialization(Book::BasicSerializer, only: %i[create])
  freeze_io!
```

If you do not want to perform input whitelisting you can use `allow_all_input` instead of `allow_input_serialization`.

### HTML output

You can define HTML outputs for example by creating a serializer that accepts `text/html`. At this moment, there may
only be one (1) active `text/html` serializer for each action; a single controller can have multiple registered, but 
never for the same preconditions in `before_action` (because how else would it know which one to pick?).

Use the `render` method to generate your HTML:
```ruby
class Book::CoverHtmlSerializer < MediaTypes::Serialization::Base
  # Tell the serializer that this accepts HTML, but this is also signaled by `to_html`
  serializes_html
  
  def to_html
    ApplicationController.render(
      'serializers/book/cover',
      assigns: {
        title: extract_title,
        image: resolve_file_url(covers.first&.version_url('small')),
        description: extract_description,
        language_links: language_links,
      },
      layout: false
    )
  end
  
  # Naturally you have to define extract_title, etc etc 
end
```

You can change the default `wrapper` / `to_html` implementation by setting:

```ruby
::MediaTypes::Serialization.html_wrapper_layout = '/path/to/wrapper/layout'
```

### API viewer

There is a special media type exposed by this gem at `::MediaTypes::Serialization::MEDIA_TYPE_API_VIEWER`. If you're
using `rails` you'll want to register it. You can do so manually, or by `require`ing:

```ruby
require 'media_types/serialization/media_type/register'
```

If you do so, the `.api_viewer` format becomes available for all actions that call into `render media:`.

You can change the default `wrapper` implementation by setting:

```ruby
::MediaTypes::Serialization.api_viewer_layout = '/path/to/wrapper/layout'
```

### Wrapping output

By convention, `index` views are wrapped in `_index: [items]`, `collection` views are wrapped in `_embedded: [items]`
and `create` / no views are wrapped in `[ROOT_KEY]: item`. This is currently only enabled for `to_json` serialization
but planned for `xml` as well.

This behaviour can not be turned of as of writing. However, you may _overwrite_ this behaviour via:

- `self.root_key(view:)`: to define the root key for a specific `view`
- `self.wrap(serializer, view: nil)`: to define the wrapper for a specific `view` and/or `serializer`. For example, if
  you never want to wrap anything, you could define:
  ```ruby
  def self.wrap(serializer, view: nil)
    serializer
  end
  ```

### Link header

You can use `to_link_header` to generate a header value for the `Link` header.

```ruby
entries = @last_media_serializer.to_link_header
if entries.present?
  response.header[HEADER_LINK] = entries
end
```

If you want the link header to be different from the `_links`, you can implement `header_links(view:)` next to 
`extract_links(view:)`. This will be called by the `to_link_header` function.

### Validation
If you only have `json`/`xml`/structured data responses and you want to use [`media_types-validation`](https://github.com/XPBytes/media_types-validation) in conjunction with this gem, you can create a concern or add the following two functions to your base controller:

```ruby
def render_media(resource = @resource, **opts)
  serializer = serialize_media(resource)
  render media: serializer, content_type: request.format.to_s, **opts
  validate_media(serializer)
end

def validate_media(serializer = @last_media_serializer)
  media_type = serializer.current_media_type
  return true unless media_type && response_body
  validate_json_with_media_type(serializer.to_hash, media_type: media_type)
end
```

As long as the serializer has a `to_json` or `to_hash`, this will work -- but also means that the data will always be validate _as if_ it were json. This covers most use cases.

### Related

- [`MediaTypes`](https://github.com/SleeplessByte/media-types-ruby): :gem: Library to create media type definitions, schemes and validations
- [`MediaTypes::Deserialization`](https://github.com/XPBytes/media_types-deserialization): :cyclone: Add media types supported deserialization using your favourite parser, and media type validation.
- [`MediaTypes::Validation`](https://github.com/XPBytes/media_types-validation): :heavy_exclamation_mark: Response validations according to a media-type

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can
also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [XPBytes/media_types-serialization](https://github.com/XPBytes/media_types-serialization).
