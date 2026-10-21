# Calendrier mensuel des interventions (date prévue), pour le tableau de bord.
# Les interventions annulées ne sont pas affichées. Les semaines commencent
# le lundi et la grille couvre des semaines entières.
class InterventionCalendar
  MAX_PER_DAY = 3

  attr_reader :month, :today

  # Lit le paramètre « 2026-10 » ; toute valeur invalide donne le mois courant.
  def self.month_from(param, today = Time.zone.today)
    Date.strptime("#{param}-01", '%Y-%m-%d').beginning_of_month
  rescue ArgumentError, TypeError
    today.beginning_of_month
  end

  def initialize(month, today: Time.zone.today)
    @month = month.beginning_of_month
    @today = today
  end

  def weeks
    (first_day..last_day).each_slice(7).to_a
  end

  def events_on(day)
    events_by_day.fetch(day, [])
  end

  def in_month?(day)
    day.month == month.month && day.year == month.year
  end

  # Intervention planifiée dont la date est dépassée.
  def overdue?(event)
    event.planned? && event.scheduled_on < today
  end

  def total
    events_by_day.slice(*(month..month.end_of_month)).values.sum(&:size)
  end

  def previous_month = month.prev_month

  delegate :next_month, to: :month

  def current_month? = month == today.beginning_of_month

  private

  def first_day = month.beginning_of_week(:monday)

  def last_day = month.end_of_month.end_of_week(:monday)

  def events_by_day
    @events_by_day ||= Event.where(scheduled_on: first_day..last_day)
                            .where.not(status: 'cancelled')
                            .includes(:equipment)
                            .order(:id)
                            .group_by(&:scheduled_on)
  end
end
