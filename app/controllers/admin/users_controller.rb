# Gestion des comptes utilisateurs, réservée aux administrateurs (UserPolicy).
# Pas de suppression : un compte se désactive par sa date de fin de validité.
module Admin
  class UsersController < ApplicationController
    before_action :set_user, only: %i[edit update deactivate reactivate]
    after_action :verify_authorized
    after_action :verify_policy_scoped, only: :index

    def index
      authorize User
      @users = policy_scope(User).includes(:departments).order(:name)
    end

    def new
      @user = User.new
      authorize @user
      load_form_data
    end

    def edit
      authorize @user
      load_form_data
    end

    def create
      @user = User.new(user_params)
      authorize @user

      if save_with_departments(@user)
        redirect_to admin_users_path, notice: "Le compte de « #{@user.name} » a été créé."
      else
        load_form_data
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @user
      @user.assign_attributes(user_params)

      if removes_last_active_admin?(@user)
        @user.errors.add(:base, 'Il doit rester au moins un administrateur actif.')
        load_form_data
        render :edit, status: :unprocessable_content
      elsif save_with_departments(@user)
        redirect_to admin_users_path, notice: "Le compte de « #{@user.name} » a été mis à jour."
      else
        load_form_data
        render :edit, status: :unprocessable_content
      end
    end

    # Désactivation immédiate : date de fin de validité fixée à la veille.
    def deactivate
      authorize @user, :update?
      @user.valid_until = Time.zone.yesterday

      if removes_last_active_admin?(@user)
        redirect_to admin_users_path, alert: 'Il doit rester au moins un administrateur actif.'
      else
        @user.save!
        @user.sessions.destroy_all
        redirect_to admin_users_path, notice: "Le compte de « #{@user.name} » est désactivé."
      end
    end

    # Réactivation : la date de fin de validité est supprimée.
    def reactivate
      authorize @user, :update?
      @user.update!(valid_until: nil)
      redirect_to admin_users_path, notice: "Le compte de « #{@user.name} » est réactivé."
    end

    private

    def set_user
      @user = User.find(params.expect(:id))
    end

    # Un mot de passe vide à la modification signifie « ne pas changer ».
    # params.fetch évite une erreur 400 quand seuls les départements sont envoyés.
    def user_params
      permitted = params.fetch(:user, {}).permit(:name, :email_address, :role, :valid_until,
                                                 :password, :password_confirmation)
      if permitted[:password].blank?
        permitted.delete(:password)
        permitted.delete(:password_confirmation)
      end
      permitted
    end

    def submitted_department_ids
      Array(params.dig(:user, :department_ids)).compact_blank.map(&:to_i)
    end

    def load_form_data
      @departments = Department.kept.order(:name)
      @selected_department_ids =
        if params[:user]
          submitted_department_ids
        else
          @user.department_memberships.pluck(:department_id)
        end
    end

    # Enregistre le compte et ses appartenances dans une seule transaction.
    def save_with_departments(user)
      User.transaction do
        raise ActiveRecord::Rollback unless user.save

        sync_departments(user, submitted_department_ids)
        user.sessions.destroy_all unless user.active?
        true
      end
    end

    # Les retraits passent par destroy pour être tracés dans le journal d'audit.
    def sync_departments(user, ids)
      ids = Department.kept.where(id: ids).pluck(:id)

      user.department_memberships.where.not(department_id: ids).find_each(&:destroy)
      (ids - user.department_memberships.pluck(:department_id)).each do |department_id|
        user.department_memberships.create!(department_id: department_id)
      end
    end

    # Empêche de se retrouver sans administrateur actif (rôle retiré ou
    # compte désactivé pour le dernier administrateur actif).
    def removes_last_active_admin?(user)
      return false if user.new_record?

      was_active = user.valid_until_was.nil? || user.valid_until_was >= Time.zone.today
      was_active_admin = user.role_was == 'admin' && was_active
      still_active_admin = user.admin? && user.active?
      return false unless was_active_admin && !still_active_admin

      User.admin.active.where.not(id: user.id).none?
    end
  end
end
