require 'action_dispatch/http/mime_type'
require 'media_types/serialization'

Mime::Type.register(MediaTypes::Serialization::MEDIA_TYPE_API_VIEWER, :api_viewer)
