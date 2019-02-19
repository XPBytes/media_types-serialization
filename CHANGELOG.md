# Changelog

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
