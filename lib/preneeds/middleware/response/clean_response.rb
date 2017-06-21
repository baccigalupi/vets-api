# frozen_string_literal: true
module Preneeds
  module Middleware
    module Response
      class CleanResponse < Faraday::Response::Middleware
        def on_complete(env)
          return unless env.url.to_s == Settings.preneeds.endpoint

          relevant_xml = env.body&.scan(%r{<S:Envelope[^<>]*>.*</S:Envelope[^<>]*>}i)&.first
          env.body = relevant_xml if relevant_xml.present?
        end
      end
    end
  end
end

Faraday::Response.register_middleware clean_response: Preneeds::Middleware::Response::CleanResponse