require 'digest'

# Jeton personnel d'API (en-tête « Authorization: Bearer … »). Il appartient à
# un utilisateur, expire, peut être révoqué, et cesse de fonctionner dès que
# le compte de l'utilisateur n'est plus actif.
class ApiToken < ApplicationRecord
  has_paper_trail skip: [:token_digest]

  PREFIX = 'mt_'.freeze
  DEFAULT_DURATION_DAYS = 365

  belongs_to :user

  # Le jeton en clair n'existe qu'en mémoire, juste après la création.
  attr_reader :plain_token

  validates :name, presence: true, length: { maximum: 80 }
  validates :expires_at, presence: true
  validates :token_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :usable, -> { where(revoked_at: nil).where('api_tokens.expires_at > ?', Time.current) }

  def self.digest(plain)
    Digest::SHA256.hexdigest(plain.to_s)
  end

  # Retourne le jeton correspondant si le jeton en clair est valide (non
  # révoqué, non expiré) et si le compte de son propriétaire est actif.
  def self.authenticate(plain)
    return if plain.blank?

    token = usable.includes(:user).find_by(token_digest: digest(plain))
    token if token&.user&.active?
  end

  def usable?
    revoked_at.nil? && expires_at > Time.current
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # Évite une écriture en base à chaque appel de l'API.
  def touch_last_used!
    return if last_used_at && last_used_at > 5.minutes.ago

    update_columns(last_used_at: Time.current)
  end

  private

  def generate_token
    @plain_token = "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = self.class.digest(@plain_token)
    self.hint = @plain_token.last(4)
    self.expires_at ||= DEFAULT_DURATION_DAYS.days.from_now
  end
end
