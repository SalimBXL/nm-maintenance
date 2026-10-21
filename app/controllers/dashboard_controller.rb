class DashboardController < ApplicationController
  after_action :verify_authorized

  def show
    authorize :dashboard, :show?
    @summary = DashboardSummary.new(Current.user)
    @calendar = InterventionCalendar.new(InterventionCalendar.month_from(params[:mois]))
  end
end
