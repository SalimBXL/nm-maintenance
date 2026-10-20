require 'test_helper'

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    @model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: @model, location: location)

    @manager = User.create!(name: 'Responsable', email_address: 'resp@example.com', password: 'secret', role: :technical_manager)
    @reporter = User.create!(name: 'Déclarant', email_address: 'decl@example.com', password: 'secret')
  end

  def upload(name = 'manuel.pdf', content = '%PDF-1.4 contenu')
    Rack::Test::UploadedFile.new(StringIO.new(content), 'application/pdf', original_filename: name)
  end

  def create_document(title: "Manuel d'utilisation", content: '%PDF-1.4 contenu', **attributes)
    document = Document.new({ title: title, equipment: @equipment }.merge(attributes))
    document.file.attach(io: StringIO.new(content), filename: "#{title.parameterize}.pdf", content_type: 'application/pdf')
    document.save!
    document
  end

  # --- Consultation

  test 'la liste exige une connexion' do
    get documents_url

    assert_redirected_to new_session_url
  end

  test "la liste n'affiche que les versions actuelles par défaut" do
    first = create_document(title: 'Manuel ancien')
    newer = Document.new(title: 'Manuel récent', equipment: @equipment, supersedes: first)
    newer.file.attach(io: StringIO.new('%PDF-1.4 v2'), filename: 'v2.pdf', content_type: 'application/pdf')
    newer.save!
    sign_in_as @reporter

    get documents_url
    assert_includes response.body, 'Manuel récent'
    assert_not_includes response.body, 'Manuel ancien'

    get documents_url(all_versions: '1')
    assert_includes response.body, 'Manuel ancien'
  end

  test "filtre par type et recherche par code d'équipement ou par modèle" do
    create_document(title: 'Manuel alpha', document_type: :manual)
    create_document(title: 'Certificat beta', document_type: :certificate, equipment: nil, equipment_model: @model)
    sign_in_as @reporter

    get documents_url(document_type: 'certificate')
    assert_includes response.body, 'Certificat beta'
    assert_not_includes response.body, 'Manuel alpha'

    get documents_url(q: @equipment.code)
    assert_includes response.body, 'Manuel alpha'
    assert_not_includes response.body, 'Certificat beta'

    get documents_url(q: 'Modèle A')
    assert_includes response.body, 'Certificat beta'
  end

  test 'filtre par validité' do
    create_document(title: 'Certificat expiré', valid_until: Time.zone.today - 10)
    create_document(title: 'Certificat valide', valid_until: Time.zone.today + 400)
    sign_in_as @reporter

    get documents_url(validity: 'expired')

    assert_includes response.body, 'Certificat expiré'
    assert_not_includes response.body, 'Certificat valide'
  end

  test 'la fiche affiche le document et son historique' do
    document = create_document
    sign_in_as @reporter

    get document_url(document)

    assert_response :success
    assert_includes response.body, 'Manuel d&#39;utilisation'
    assert_includes response.body, 'Historique des versions'
  end

  test 'le téléchargement renvoie le fichier en pièce jointe' do
    document = create_document(content: '%PDF-1.4 contenu secret')
    sign_in_as @reporter

    get download_document_url(document)

    assert_response :success
    assert_equal '%PDF-1.4 contenu secret', response.body
    assert_includes response.headers['Content-Disposition'], 'attachment'
  end

  test 'le téléchargement exige une connexion' do
    document = create_document

    get download_document_url(document)

    assert_redirected_to new_session_url
  end

  test "les fiches équipement montrent les documents de l'équipement et de son modèle" do
    create_document(title: 'Procédure locale')
    create_document(title: 'Manuel du modèle', equipment: nil, equipment_model: @model)
    sign_in_as @reporter

    get equipment_url(@equipment)

    assert_includes response.body, 'Procédure locale'
    assert_includes response.body, 'Manuel du modèle'
  end

  # --- Ajout

  test 'un déclarant ne peut pas ajouter de document' do
    sign_in_as @reporter

    get new_document_url
    assert_redirected_to root_path

    assert_no_difference -> { Document.count } do
      post documents_url,
           params: { document: { title: 'X', equipment_id: @equipment.id, target_kind: 'equipment', file: upload } }
    end
  end

  test 'le responsable technique ajoute un document à un équipement' do
    sign_in_as @manager

    assert_difference -> { Document.count } => 1 do
      post documents_url, params: {
        document: { title: 'Rapport de contrôle', document_type: 'report', target_kind: 'equipment',
                    equipment_id: @equipment.id, equipment_model_id: @model.id, valid_until: '2027-06-30', file: upload }
      }
    end

    document = Document.last
    assert_redirected_to document_url(document)
    assert_equal @equipment, document.equipment
    assert_nil document.equipment_model
    assert_equal @manager, document.uploaded_by
    assert document.file.attached?
    assert_equal Date.new(2027, 6, 30), document.valid_until
  end

  test 'le responsable technique ajoute un document à un modèle' do
    sign_in_as @manager

    post documents_url, params: {
      document: { title: 'Manuel', document_type: 'manual', target_kind: 'model',
                  equipment_id: @equipment.id, equipment_model_id: @model.id, file: upload }
    }

    document = Document.last
    assert_equal @model, document.equipment_model
    assert_nil document.equipment
  end

  test 'un ajout sans fichier réaffiche le formulaire' do
    sign_in_as @manager

    assert_no_difference -> { Document.count } do
      post documents_url, params: { document: { title: 'Manuel', target_kind: 'equipment', equipment_id: @equipment.id } }
    end

    assert_response :unprocessable_entity
  end

  # --- Versions

  test 'le responsable technique ajoute une nouvelle version' do
    first = create_document
    sign_in_as @manager

    get new_version_document_url(first)
    assert_response :success

    assert_difference -> { Document.count } => 1 do
      post create_version_document_url(first), params: {
        document: {
          title: first.title,
          version_label: '2.0',
          notes: 'Chapitre sécurité ajouté',
          file: upload('manuel-v2.pdf', '%PDF-1.4 v2')
        }
      }
    end

    newer = Document.last
    assert_redirected_to document_url(newer)
    assert_equal 2, newer.version_number
    assert_equal first, newer.supersedes
    assert_equal @equipment, newer.equipment
    assert_not first.reload.current?
  end

  test 'on ne peut pas créer une version sur une version déjà remplacée' do
    first = create_document
    newer = Document.new(title: first.title, equipment: @equipment, supersedes: first)
    newer.file.attach(io: StringIO.new('%PDF-1.4 v2'), filename: 'v2.pdf', content_type: 'application/pdf')
    newer.save!
    sign_in_as @manager

    get new_version_document_url(first)
    assert_redirected_to root_path

    assert_no_difference -> { Document.count } do
      post create_version_document_url(first), params: { document: { title: first.title, file: upload } }
    end
  end

  # --- Modification et archivage

  test 'le responsable technique modifie les informations mais pas le rattachement' do
    document = create_document
    sign_in_as @manager

    patch document_url(document), params: { document: { title: 'Manuel révisé', valid_until: '2028-01-01', equipment_id: nil } }

    assert_redirected_to document_url(document)
    document.reload
    assert_equal 'Manuel révisé', document.title
    assert_equal @equipment, document.equipment
  end

  test 'un document peut être archivé puis réactivé' do
    document = create_document
    sign_in_as @manager

    post archive_document_url(document)
    assert document.reload.archived?

    post unarchive_document_url(document)
    assert_not document.reload.archived?
  end

  test 'un déclarant ne peut pas archiver' do
    document = create_document
    sign_in_as @reporter

    post archive_document_url(document)

    assert_not document.reload.archived?
  end
end
