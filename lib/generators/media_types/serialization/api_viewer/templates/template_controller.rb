module Api
  class TemplateController < ApiController
    def create
      href = params[:template].delete(:href)
      templated_values = params[:template].permit!.to_h

      response["Location"] = templated_values.reduce(href) do |result, (key, value)|
        result.sub!(%r{:#{key}|{#{key}}|%7B#{key}%7D}, value) || invalid_parameter(key, href)
      end
      head :temporary_redirect
    end

    private

    def invalid_parameter(key, href)
      raise ActionController::BadRequest, format(
        'Received templated value for "%<key>s" which does not exist in templated link "%<href>s"',
        key: key,
        href: href.gsub('%7B', '{').gsub('%7D', '}')
      )
    end
  end
end
