# frozen_string_literal: true

require 'erb'
require 'base64'
require 'active_support'

module MediaTypes
  module Serialization
    module Serializers
      module CommonCSS

        mattr_accessor :logo_data, :logo_media_type, :logo_width, :background, :custom_css

        self.background = 'linear-gradient(245deg, rgba(255,89,89,1) 0%, rgba(255,164,113,1) 100%)'
        self.logo_media_type = 'image/svg+xml'
        self.logo_width = 8
        self.logo_data = <<-HERE
          <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 114 93">
            <title>Delft Solutions</title>

            <filter id="dropshadow">
              <feGaussianBlur in="SourceAlpha" stdDeviation="1"></feGaussianBlur> <!-- stdDeviation is how much to blur -->
              <feOffset dx="2" dy="1" result="offsetblur"></feOffset> <!-- how much to offset -->
              <feComponentTransfer>
                <feFuncA type="linear" slope="0.5"></feFuncA> <!-- slope is the opacity of the shadow -->
              </feComponentTransfer>
              <feMerge>
                <feMergeNode></feMergeNode> <!-- this contains the offset blurred image -->
                <feMergeNode in="SourceGraphic"></feMergeNode> <!-- this contains the element that the filter is applied to -->
              </feMerge>
            </filter>

            <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
              <g fill="#FFFFFF" fill-rule="nonzero">

                <path d="M81.5784638,1.07718279e-13 C82.7664738,1.07718279e-13 83.8032488,0.734079641 84.4157016,1.75205281 L109.531129,43.5095713 C110.813908,45.6417099 110.657922,48.2974919 109.15835,50.2831454 L80.6973102,87.9923196 C80.0557678,88.7870619 79.0855103,89.3973447 78.0602378,89.3973447 L42.8594985,89.3973447 L14.6289023,43.5796094 L38.1043811,13.5281311 L47.8307983,13.5281311 L25.7347121,43.6175319 L48.0361926,79.9158441 L75.0253918,79.9158441 L101.326814,46.2820182 L73.5454136,1.07718279e-13 L81.5784638,1.07718279e-13 Z M68.8174965,0.000338312914 L96.4191607,45.9808751 L73.2382461,75.6684695 L61.4283598,75.6684695 L84.975762,45.385564 L63.4142078,9.46643441 L36.1380842,9.46643441 L9.60299852,43.3032035 L35.9112712,85.3931029 L38.1241857,89.3191214 L29.1498474,89.3973434 C27.9592604,89.4075947 26.8506993,88.7919375 26.2302294,87.7757572 L0.893096605,46.2796422 C-0.418595034,44.1314075 -0.274907213,41.3978442 1.25477457,39.3989643 L30.388821,1.32865425 L30.4563519,1.24328222 C31.0981823,0.458113729 32.0600455,0.000338312914 33.0779839,0.000338312914 L68.8174965,0.000338312914 Z" id="logo-mark-colour"></path>
              </g>
            </g>
          </svg>
        HERE

        def self.logo_url
          "data:#{logo_media_type};base64,#{Base64.encode64(logo_data).tr("\n", '')}"
        end

        def self.css
          template = ERB.new <<-TEMPLATE
          html {
            min-height: 100%;
            background: <%= background %>;
          }
          
          body {
            color: #fff;
            margin-left: 2em;
            margin-right: 2em;
            margin-top: 1em;
            max-width: 1200px;
          
            font-family: -apple-system, ".SFNSText-Regular", "San Francisco", "Roboto", "Segoe UI", "Helvetica Neue", "Lucida Grande", sans-serif;
            font-size: 16px;
            line-height: 1.6;
            -webkit-font-feature-settings: "kern","liga","clig","calt";
            font-feature-settings: "kern","liga","clig","calt";
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale
            overflow-x: hidden;
          }
          
          main {
            max-width: 100%;
          }
          
          header {
            display: inline-block;
            max-width: 100%;
          }
          
          a:link {
            color: #007bff;
          }
          a:visited {
            color: #9c27b0;
          }
          a:hover {
            color: #00bcd4;
          }
          
          #logo {
            width: <%= logo_width %>em;
            height: 5em;
            background-repeat: no-repeat;
            background-position-x: right;
            background-position-y: center;
            background-image: url(<%= logo_url %>);
            float: left;
            margin-right: 2em;
          }
          
          header h1 {
            clear: right;
            text-overflow: ellipsis;
            white-space: nowrap;
            overflow: hidden;
          
            font-size: 1.5em;
            line-height: 2em;
          }
          
          #content {
            margin-top: 1em;
            padding-left: 1em;
            padding-right: 1em;
            padding-bottom: 1em;
            color: #060B34;
            background-color: #fff;
            border-radius: 1em;
            border: 1px solid #E0E1E4;
            overflow: auto;
          }
          
          nav h2 {
            font-size: 1em;
            line-height: 1.25em;
            margin-bottom: 0;
          }
          nav .label {
            float: left;
          }
          
          nav ul {
            clear: right;
            display: inline-block;
            margin: 0;
            padding: 0;
          }
          nav li {
            float: left;
            list-style: none;
            margin-right: 0.3em;
          }
          nav li a.active {
            font-weight: bold;
          }
          nav li a.active:link, nav li a.active:visited {
            color: #060B34;
          }
          nav li + li:before {
            content: "|";
            margin-right: 0.3em;
          }
          
          nav #representations {
            margin-bottom: 1em;
          }
          nav hr {
            border: none;
            border-top: solid 1px #E0E1E4;
          }
          
          nav #links {
            display: inline-block;
            margin-bottom: 1em;
          }
          nav #links ul {
            float: left;
          }
          
          #output {
            font-size: .9em;
          }
          
          TEMPLATE
          template = ERB.new custom_css unless custom_css.nil?

          template.result(binding)
        end
      end
    end
  end
end
