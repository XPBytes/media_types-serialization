# MediaTypes::Serialization

[![Build Status: master](https://travis-ci.com/XPBytes/media_types-serialization.svg)](https://travis-ci.com/XPBytes/media_types-serialization)
[![Gem Version](https://badge.fury.io/rb/media_types-serialization.svg)](https://badge.fury.io/rb/media_types-serialization)
[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)

Add media types supported serialization using your favourite serializer

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

In order to use media type serialization you only need to do 2 things:

### Serializer

Add a serializer that can serialize a certain media type. The `to_hash` function will be called _explicitely_ in your
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

    private

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
the latest version you `MediaType` is reporting.

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
    
      # This is called if the version is 1 _or_ lower. This means you can compose your migrations
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
uses the serialization, you need to explicitely `accept` it if you want to use the built-in lookups.

```ruby
require 'media_types/serialization'

class ApiController < ActionController::API
  include MediaTypes::Serialization
  
  def render_json_media(media, status: :ok)
    # Because this is JSON, we expect a hash. If this were html, you might generate
    # xml / xpath with to_xml, or a string using to_s.
    # 
    render json: serialize_media(media).to_hash,
           status: status,
           content_type: request.format.to_s
  end
  
  def render_html_media(media, status: :ok)
    render serializer(media).to_html,
           status: status,
           content_type: request.format.to_s
  end
 
end

class BookController < ApiController

  accept_serialization(Book::BasicSerializer, accept_html: false, only: %i[show])
  accept_html(Book::CoverHtmlSerializer, only: %i[show])
  freeze_accepted_media!
      
  def show 
    request.format.to_s == 'text/html' ? render_html_media(@book) : render_json_media(@book)
  end
end
```

### HTML output

You can define HTML outputs for example by creating a serializer that accepts `text/html`. At this moment, there may
only be one (1) active HTML serializer for each action; a single controller can have multiple registered, but never for
the same preconditions in `before_action` (because how else would it know which one to pick?).

Use the `render` method to generate your HTML:
```ruby
class Book::CoverHtmlSerializer < MediaTypes::Serialization::Base
  # Tell the serializer that this accepts HTML
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

By default, this method only outputs to `stderr` when something is wrong; see configuration below if you want to assign
your own behaviour, such as adding a `Warn` header, or raising a server error.

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
