# Changelog

## 2.0.3

- 🐛 Fix debian packages not containing files

## 2.0.0

- ✨ Add support for loose input validation
- ✨ Add inline api call functionality to api_viewer
- ✨ `allow_html_output` will now get the object in the `media` variable and if it is a hash, elements will be assigned as locals
- 🐛 Fix wildcards not showing up for non-nil views
- 🐛 Sending invalid content returned a 422 status code, changed to 400

## 1.4.0

- ✨ Add support for redirecting in serializers

## 1.3.9

- ✨ Make serializer look slightly better on mobile by zooming in initially

## 1.3.8

## 1.3.7

- 🐛 Fix execution context for `output_error`

## 1.3.6

- 🐛 Fix issue with `override_detail` of `Problem`

## 1.3.5

- 🐛 Upgrade media-types library so Ruby 2.5 and 2.6 work again

## 1.3.4

- Same as `1.3.3`

## 1.3.3

- 🐛 Fix override suffix not being picked up correctly
- 🐛 Fix inability to override suffix for aliases
- 🐛 Fix inability to override suffix for raw
- 🐛 Fix default suffix for raw

## 1.3.2

- 🐛 Fix override suffix not returning self or new

## 1.3.1

- 🐛 Fix api viewer
- 🐛 Fix `output_raw` suffix (`+json` needs to be `''`)

## 1.3.0

- ✨ Add `formats:` to `output_html` and default it to `[:html]`, so rails behaves
- 🐛 Fix stale references to `render media:`
- 🐛 Fix inconsistent `context:` passing for `Serializer.serialize`

## 1.2.0

- ✨ Add `view:` to `output_html` which renders a specific rails view.

## 1.1.0

- ✨ Add _allow_output_html_: Fallback to rails rendering.
- ✨ Add _allow_output_docs_: Useful to add a documentation description to endpoints that you can normally only POST to.
- ✨ Add _output_error_: Implements missing content-language support.
- ✨ Add _scoped freeze_io! support_: Useful for gradual adoption of mediatypes on existing routes.
- ✨ Add _alias variant reporting_: Allows reporting what the original matched media type was even when impersonating a different media type.
- ✨ Improve README: small improvements to make it easier to adopt and upgrade existing codebase.
- ✨ Reduce number of (external) dependencies
- 🐛 Fix incorrect output on encoding errors.
- 🐛 Fix message in various alias error messages.

## 1.0.3

- 🐛 Unvalidated serializers would put the view part of the identifier before the version. This was not in line with validated serializers.

## 1.0.2

- 🐛 Explicitly set all oj parameters when decoding as well.

## 1.0.1

- 🐛 Explicitly set all oj and json parameters to ensure correct behavior with changed defaults.
- 🐛 Fix serializer not deserializing as symbols.

## 1.0.0

- ✨ Add support for input deserialization.
- ✨ Add serializer DSL to be more in line with validation gem.
- ✨ Add ability to make a serializer without a validator.
- ✨ Add error serializer that emits [`application/problem+json`](https://tools.ietf.org/html/rfc7231).
- ✨ Reduce number of dependencies.
- ✨ Validators no longer need to be registered to be used.
- ✨ Add a [wiki where errors can be documented](https://docs.delftsolutions.nl). Feel free to make pages for your own namespaced errors.
- 💔 Serializer definition API has backwards incompatible changes.
- 💔 API viewer is now no longer registered as html but accessible with the `?api_viewer=last` query parameter.
- 💔 Validators can no longer be registered for use in `format do`.

## 0.8.1

- 🐛 Fix collection wrappers sometimes sending the wrong data to serializers

## 0.8.0

- ✨ Add support for having multiple link headers with the same `rel`

## 0.7.0

- ✨ Add `extract_set_links` to serializer for collection links

## 0.7.0.beta1

- 🐛 Fix non-serializer media types replacing known serializers
- 🐛 Fix passed in media type for HTML as fallback (actual type instead of html)
- 🐛 Fix passed in media type for API Viewer (actual type instead of API Viewer)
- 🐛 Fix migrations failing on versioning text/html
- 🐛 Fix HTML non-overwrite logic (first one wins, unless there is an override)
- ✨ Add `api_viewer_media_type` param for api viewers to set the serialization type
- ✨ Add api viewer links in the api viewer:
  - For representations: use `.api_viewer` unless it's `.html`
  - For body links: use .api_viewer unless it already has a `.format`
  - For HTTP links: leave them alone

## 0.6.2

- 🐛 Update `http_headers-accept`: 0.2.1 → 0.2.2

## 0.6.1

- 🚨 Update nokogiri: 1.10.1 → 1.10.3

## 0.6.0

- Add `accept_api_viewer` which is on by default
- Add `overwrite` parameter to `accept_html`
- Add `api_viewer_layout` configuration option
- Add generator to initialize the gem and copy the API Viewer

## 0.5.1

- Correctly expose `current_media_type` and `current_view`
- Fix cyclic requires
- Add documentation for overwriting wrappers

## 0.5.0

- Change wrappers to extend from `SimpleDelegator`
- Move `RootKey` to `Base.root_key` method so it can be overridden
- Move `MediaWrapper.wrap` to `Base.wrap` method so it can be overridden
- Move `MediaObjectWrapper::AUTO_UNWRAP_KLAZZES` to `MediaObjectWrapper.auto_unwrap_klazzes` option
- Add `::MediaTypes::Serialization.html_wrapper_layout` option
- Add `MediaObjectWrapper#unwrapped_serializable` which can be overridden in `Base#unwrapped_serializable`
- Add `MediaIndexWrapper#wrapped_serializable` which can be overridden in `Base#wrapped_serializable`
- Add `MediaCollectionWrapper#wrapped_serializable` which can be overridden in `Base#wrapped_serializable`
- Fix empty link handler (`{ rel: nil }`)
- Fix `NoSerializerForContentType` error message
- Add tests for `root_key`, `wrap`, `MediaObjectWrapper`, `MediaIndexWrapper` and `MediaCollectionWrapper`

## 0.4.0

- Change `extract_links` to `extract_links(view:)` and mimic `header_links(view:)`
- Use `extract_links` in `index` and `collection` wrapper output

## 0.3.2

- Rename `collect_links` to `header_links` to actually expose the links

## 0.3.1

- Fix classes sharing `media_type_constructable`, `serializes_html_flag` and `media_type_versions`
- Change `instance_methods(false)` check to `instance_methods` check in `MimeTypeSupport`
- Add `view` to `header_links` call
- Add `collect_links_for_index` option to collect links for index views
- Add `collect_links_for_collection` option to collect links for collection views

## 0.3.0

- Change `to_link_header` to return a string ready to be used as header
- Change `header_links` to actually return the links for the header in object form

## 0.2.0

- Change `method_missing` and base methods for `Base`
- Add test for `HtmlWrapper`

## 0.1.0

:baby: initial release
