module Api
  module V1
    class MeController < BaseController
      # GET /api/v1/me : l'utilisateur identifié par le jeton.
      def show
        skip_authorization
        render json: { data: ApiSerializers.user(Current.user) }
      end
    end
  end
end
