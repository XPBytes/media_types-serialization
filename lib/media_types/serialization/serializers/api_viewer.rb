# frozen_string_literal: true

require 'media_types/serialization/base'
require 'erb'
require 'cgi'

module MediaTypes
  module Serialization
    module Serializers
      class ApiViewer < MediaTypes::Serialization::Base
        unvalidated 'text/html'

        def self.viewerify(uri, current_host, type: 'last')
          viewer = URI.parse(uri)

          return uri unless viewer.host == current_host

          query_parts = viewer.query&.split('&') || []
          query_parts = query_parts.reject { |p| p.starts_with?('api_viewer=') }
          query_parts.append("api_viewer=#{type}")
          viewer.query = query_parts.join('&')
          viewer.to_s
        end

        def self.to_input_identifiers(serializers)
          serializers.flat_map do |s|
            s[:serializer].inputs_for(views: [s[:view]]).registrations.keys
          end
        end
        def self.to_output_identifiers(serializers)
          serializers.flat_map do |s|
            s[:serializer].outputs_for(views: [s[:view]]).registrations.keys
          end
        end

        def self.allowed_replies(context, actions)
          request_path = context.request.original_fullpath.split('?')[0]

          path_prefix = ENV.fetch('RAILS_RELATIVE_URL_ROOT') { '' }
          request_path = request_path.sub(path_prefix, '')

          my_controller = Rails.application.routes.recognize_path request_path
          possible_replies = ['POST', 'PUT', 'DELETE']
          enabled_replies = {}
          possible_replies.each do |m|
            begin
              found_controller = Rails.application.routes.recognize_path request_path, method: m
              if found_controller[:controller] == my_controller[:controller]
                enabled_replies[m] = found_controller[:action]
              end
            rescue ActionController::RoutingError
              # not available
            end
          end

          input_definitions = actions[:input] || {}
          output_definitions = actions[:output] || {}

          result = {}
          global_in = input_definitions['all_actions'] || []
          global_out = output_definitions['all_actions'] || []

          viewer_uri = URI.parse(context.request.original_url)
          query_parts = viewer_uri.query&.split('&') || []
          query_parts = query_parts.select { |q| !q.start_with? 'api_viewer=' }
          viewer_uri.query = (query_parts + ["api_viewer=last"]).join('&')

          enabled_replies.each do |method, action|
            input_serializers = global_in + (input_definitions[action] || [])
            output_serializers = global_out + (output_definitions[action] || [])
            result[method] = {
              input: to_input_identifiers(input_serializers),
              output: to_output_identifiers(output_serializers),
            }
          end

          result
        end

        def self.escape_javascript(value)
          escape_map = {
            "\\"    => "\\\\",
            "</"    => '<\/',
            "\r\n"  => '\n',
            "\n"    => '\n',
            "\r"    => '\n',
            '"'     => '\\"',
            "'"     => "\\'",
            "`"     => "\\`",
            "$"     => "\\$"
          }
          escape_map[(+"\342\200\250").force_encoding(Encoding::UTF_8).encode!] = "&#x2028;"
          escape_map[(+"\342\200\251").force_encoding(Encoding::UTF_8).encode!] = "&#x2029;"

          value ||= ""

          return value.gsub(/(\\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"']|[`]|[$])/u, escape_map).html_safe
        end

        output_raw do |obj, version, context|
          original_identifier = obj[:identifier]
          registrations = obj[:registrations]
          original_output = obj[:output]
          original_links = obj[:links]

          api_fied_links = original_links.map do |l|
            new = l.dup
            new[:invalid] = false
            begin
              uri = viewerify(new[:href], context.request.host)
              new[:href] = uri.to_s
            rescue URI::InvalidURIError
              new[:invalid] = true
            end

            new
          end

          media_types = registrations.registrations.keys.map do |identifier|
            result = {
              identifier: identifier,
              href: viewerify(context.request.original_url, context.request.host, type: identifier),
              selected: identifier == original_identifier
            }
            result[:href] = '#output' if identifier == original_identifier

            result
          end

          escaped_output = original_output
            &.split("\n")
            &.map { |l| CGI.escapeHTML(l).gsub(/ (?= )/, '&nbsp;') }
            &.map do |l|
              l.gsub(/\bhttps?:\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;{}]*[-A-Z0-9+@#\/%=}~_|](?![a-z]*;)/i) do |m|
                converted = m
                invalid = false
                begin
                  converted = viewerify(m, context.request.host)
                rescue URI::InvalidURIError
                  invalid = true
                end
                style = ''
                style = ' style="color: red"' if invalid
                "<a#{style} href=\"#{converted}\">#{m}</a>"
              end
            end
            &.join("<br>\n")

          unviewered_uri = URI.parse(context.request.original_url)
          query_parts = unviewered_uri.query&.split('&') || []
          query_parts = query_parts.select { |q| !q.start_with? 'api_viewer=' }
          unviewered_uri.query = query_parts.join('&')

          input = OpenStruct.new(
            original_identifier: original_identifier,
            escaped_output: escaped_output,
            api_fied_links: api_fied_links,
            media_types: media_types,
            css: CommonCSS.css,
            etag: obj[:etag],
            allowed_replies: allowed_replies(context, obj[:actions]),
            escape_javascript: method(:escape_javascript),
            unviewered_uri: unviewered_uri
          )

          template = ERB.new <<-TEMPLATE
            <!DOCTYPE html>
            <html lang="en">
              <head>
                <meta content="width=device-width, initial-scale=1" name="viewport">

                <title>API Viewer [<%= CGI::escapeHTML(original_identifier) %>]</title>
                <style>
                  <%= css.split("\n").join("\n      ") %>
                </style>
              </head>
              <body>
                <header>
                  <div id="logo"></div>
                  <h1>Api Viewer - <%= CGI::escapeHTML(original_identifier) %></h1>
                </header>
                <section id="content">
                  <nav>
                    <section id="representations">
                      <h2>Representations:</h2>
                      <ul>
                        <% media_types.each do |m| %>
                        <li>
                          <a href="<%= m[:href] %>" <%= m[:selected] ? 'class="active" ' : '' %>>
                            <%= CGI::escapeHTML(m[:identifier]) %>
                          </a>
                        </li>
                        <% end %>
                      </ul>
                      <hr>
                    </section>
                    <section id="links">
                      <span class="label">Links:&nbsp</span>
                      <ul>
                        <% api_fied_links.each do |l| %>
                        <li><a <% if l[:invalid] %> style="color: red" <% end %>href="<%= l[:href] %>"><%= CGI::escapeHTML(l[:rel].to_s) %></a></li>
                        <% end %>
                      </ul>
                    </section>
                  </nav>
                  <% if allowed_replies.any? %>
                    <section id="reply">
                      <details>
                        <summary>Reply</summary>
                        <div class="reply-indent">
                          <noscript>Javascript is required to submit custom responses back to the server</noscript>
                          <form id="reply-form" hidden>
                            <div class="form-table">
                              <label class="form-row">
                                <div class="cell label">Method:</div>
                                <% if allowed_replies.keys.count == 1 %>
                                  <input type="hidden" name="method" value="<%= allowed_replies.keys[0] %>">
                                  <div class="cell"><%= allowed_replies.keys[0] %></div>
                                <% else %>
                                  <select class="cell" name="method">
                                    <% allowed_replies.keys.each do |method| %>
                                      <option value="<%= method %>"><%= method %></option>
                                    <% end %>
                                  </select>
                                <% end %>
                              </label>
                              <label class="form-row"><div class="cell label">Send:</div> <select class="cell" name="request-content-type"></select></label>
                              <label class="form-row"><div class="cell label">Receive:</div> <select class="cell" name="response-content-type"></select></label>
                            </div>
                            <textarea name="request-content"></textarea>
                            <input type="button" name="submit" value="Reply"><span id="reply-status-code" hidden> - sending...</span> 
                            <hr>
                            <code id="reply-response" hidden>
                            </code>
                          </form>
                          <script>
                            {
                              let form = document.getElementById("reply-form")
                              form.removeAttribute('hidden')

                              let action_data = JSON.parse("<%= escape_javascript.call(allowed_replies.to_json) %>")

                              let methodElem = form.elements["method"]
                              let requestTypeElem = form.elements["request-content-type"]
                              let responseTypeElem = form.elements["response-content-type"]
                              let contentElem = form.elements["request-content"]
                              let submitElem = form.elements["submit"]
                              let replyResponseElem = document.getElementById("reply-response")
                              let replyStatusCodeElem = document.getElementById("reply-status-code")
                              let selectRequestType = function() {
                                let selected = requestTypeElem.value

                                if (selected == "")
                                  contentElem.setAttribute("hidden", "")
                                else
                                  contentElem.removeAttribute("hidden")
                                
                                if (methodElem.value == "PUT" && contentElem.value.trim() == "") {
                                  let currentRequestType = document.querySelector("#representations .active").textContent.trim()
                                  if (currentRequestType == requestTypeElem.value) {
                                    let outputElem = document.getElementById("output")
                                    contentElem.value = outputElem.
                                      textContent.
                                      trim().
                                      replaceAll(String.fromCharCode(160), " ")
                                  }
                                }
                              }

                              let selectMethod = function() {
                                let selected = methodElem.value
                                submitElem.setAttribute("value", selected)

                                let mediatypes = action_data[selected]

                                while(requestTypeElem.firstChild)
                                  requestTypeElem.removeChild(requestTypeElem.lastChild)
                                mediatypes["input"].forEach(mediatype => {
                                  let option = document.createElement("option")
                                  option.setAttribute("value", mediatype)
                                  option.textContent = mediatype
                                  requestTypeElem.appendChild(option)
                                })
                                let noneOption = document.createElement("option")
                                noneOption.setAttribute("value", "")
                                noneOption.textContent = "None"
                                requestTypeElem.appendChild(noneOption)

                                while(responseTypeElem.firstChild)
                                  responseTypeElem.removeChild(responseTypeElem.lastChild)
                                mediatypes["output"].forEach(mediatype => {
                                  let option = document.createElement("option")
                                  option.setAttribute("value", mediatype)
                                  option.textContent = mediatype
                                  responseTypeElem.appendChild(option)
                                })
                                let anyOption = document.createElement("option")
                                anyOption.setAttribute("value", "")
                                anyOption.textContent = "Any"
                                responseTypeElem.appendChild(anyOption)

                                selectRequestType()
                              }

                              let onSubmit = async function() {
                                submitElem.setAttribute("disabled", "")
                                let method = methodElem.value
                                let requestContentType = requestTypeElem.value
                                let requestContent = contentElem.value
                                var responseAccept = responseTypeElem.value + ", application/problem+json; q=0.2, */*; q=0.1"
                                if (responseTypeElem.value == "")
                                  responseAccept = "application/problem+json, */*; q=0.1"

                                let headers = {
                                  Accept: responseAccept,
                                }
                                if (method == "PUT") {
                                  let etag = "<%= escape_javascript.call(etag) %>"
                                  if (etag != "") {
                                    headers['If-Match'] = etag
                                  }
                                }
                                let body = undefined
                                if (requestContentType != "") {
                                  headers["Content-Type"] = requestContentType
                                  body = requestContent
                                }

                                replyResponseElem.textContent = ""
                                replyStatusCodeElem.textContent = " - sending..."
                                replyStatusCodeElem.removeAttribute("hidden")

                                try {
                                  let response = await fetch("<%= escape_javascript.call(unviewered_uri.to_s) %>", {
                                    method: method,
                                    mode: "same-origin",
                                    credentials: "same-origin",
                                    redirect: "follow",
                                    headers: headers,
                                    body: body
                                  })

                                  replyStatusCodeElem.textContent = " - Status " + response.status + " " + response.statusText
                                  replyResponseElem.removeAttribute("hidden")
                                  replyResponseElem.textContent = await response.text()
                                  replyResponseElem.innerHTML = replyResponseElem.
                                    innerHTML.
                                    replaceAll("\\n", "<br>\\n").
                                    replaceAll("  ", "&nbsp; ")
                                } catch (error) {
                                  replyStatusCodeElem.textContent = " - Failed: " + error.message
                                } finally {
                                  submitElem.removeAttribute("disabled")
                                }
                              }

                              requestTypeElem.addEventListener("change", (e) => selectRequestType())
                              methodElem.addEventListener("change", (e) => selectMethod())
                              submitElem.addEventListener("click", (e) => onSubmit())

                              addEventListener("DOMContentLoaded", (event) => selectMethod());
                            }
                          </script>
                        </div>
                      </details>
                    </section>
                  <% end %>
                  <main>
                    <code id="output">
                      <%= escaped_output %>
                    </code>
                  </main>
                </section>
                <!-- API viewer made with ❤ by: https://delftsolutions.com -->
              </body>
            </html>
          TEMPLATE
          template.result(input.instance_eval { binding })
        end
      end
    end
  end
end
