module Api
  module V1
    # GET /api/v1/openapi.yaml : spécification OpenAPI, sans authentification
    # (elle ne contient aucune donnée, et sert à générer les clients).
    class OpenapiController < BaseController
      skip_before_action :authenticate!
      skip_after_action :verify_authorized

      def show
        send_file Rails.root.join('openapi/v1.yaml'), type: 'application/yaml', disposition: 'inline'
      end
    end
  end
end
