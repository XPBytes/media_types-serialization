# Changelog

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
