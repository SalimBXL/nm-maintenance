class DashboardController < ApplicationController
  after_action :verify_authorized

  def show
    authorize :dashboard, :show?
    @summary = DashboardSummary.new(Current.user)
  end
end
