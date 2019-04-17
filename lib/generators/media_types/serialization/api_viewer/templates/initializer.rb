require 'media_types/serialization'

# This registers the renderer as side-effect
require 'media_types/serialization/renderer/register'

# This registers the media type as side-effect
require 'media_types/serialization/media_type/register'

##
# The following options are breaking and therefore disabled by default.
#
# When these are true, the +header_links+ and +extract_links+ methods is called
# when dealing with a .collection or .index view, respectively. It allows you
# to define +_links+ for the root level from your serializer.
#
#
# MediaTypes::Serialization.collect_links_for_collection = true
# MediaTypes::Serialization.collect_links_for_index = true

##
# The API Viewer template is provided if you used the generator. You can change
# the view it renders by changing the path below.
#
#
# ::MediaTypes::Serialization.api_viewer_layout = '/path/to/wrapper/layout'

##
# When .to_html is not provided by a serializer, it will fall back to render
# the API Viewer, but this template can be changed by changing the path
# below.
#
#
# ::MediaTypes::Serialization.html_wrapper_layout = '/path/to/wrapper/layout'
