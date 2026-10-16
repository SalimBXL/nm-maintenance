require "csv"

# Import initial du parc par fichier CSV ou Excel (.xlsx).
#
# Deux temps, comme prévu par la spécification :
#   1. analyse   : EquipmentImport.from_csv(...) / from_xlsx(...) / from_upload(...)
#                  -> errors (ligne par ligne), new_locations, new_models, rows
#   2. validation: import.commit! crée tout dans UNE transaction ; si le
#                  fichier est invalide, rien n'est importé.
#
# Colonnes obligatoires : categorie, fabricant, modele, departement, local.
# Colonnes facultatives : numero_serie, criticite, date_acquisition,
# date_mise_en_service, fin_garantie, notes.
# Il n'y a PAS de colonne « code » : le code interne est toujours généré
# par l'application (TYPE-FABRICANT-NN).
#
# Valeurs reconnues sans tenir compte de la casse ni des accents :
#   categorie   : nom ou préfixe de la catégorie (ex. « SPECT », « PET-CT »)
#   fabricant   : nom ou code court (ex. « GE », « VIK »)
#   departement : nom ou code
#   local       : nom ou code, dans ce département
# Locaux et modèles inconnus : proposés à la création dans l'aperçu.
# Départements, catégories et fabricants inconnus : erreur (ils se créent
# dans l'administration, où un code doit être choisi).
class EquipmentImport
  class Invalid < StandardError; end

  Error = Struct.new(:line, :message)
  PlannedRow = Struct.new(:line, :model, :model_key, :location, :location_key, :attributes, keyword_init: true)

  HEADER_NAMES = {
    category: "categorie",
    manufacturer: "fabricant",
    model: "modele",
    department: "departement",
    location: "local",
    serial_number: "numero_serie",
    criticality: "criticite",
    acquired_on: "date_acquisition",
    commissioned_on: "date_mise_en_service",
    warranty_ends_on: "fin_garantie",
    notes: "notes"
  }.freeze

  HEADERS = HEADER_NAMES.invert.merge(
    "numero_de_serie" => :serial_number,
    "date_de_mise_en_service" => :commissioned_on,
    "date_de_fin_de_garantie" => :warranty_ends_on
  ).freeze

  REQUIRED = %i[category manufacturer model department location].freeze

  CRITICALITIES = {
    "faible" => "low", "low" => "low",
    "moyenne" => "medium", "moyen" => "medium", "medium" => "medium",
    "haute" => "high", "elevee" => "high", "high" => "high"
  }.freeze

  SEPARATORS = [ ";", ",", "\t" ].freeze

  attr_reader :errors, :rows

  # ---------- Lecture du fichier ----------

  def self.from_csv(content)
    new(read_csv(content))
  rescue CSV::MalformedCSVError => e
    new([], read_error: "Fichier CSV illisible : #{e.message}")
  end

  def self.from_xlsx(path)
    new(read_xlsx(path))
  end

  # upload : fichier envoyé depuis un formulaire (ActionDispatch::Http::UploadedFile)
  def self.from_upload(upload)
    if upload.original_filename.to_s.downcase.end_with?(".xlsx")
      from_xlsx(upload.path)
    else
      from_csv(upload.read)
    end
  end

  # Modèle de fichier à fournir aux utilisateurs (CSV avec « ; » et BOM UTF-8,
  # pour une ouverture correcte dans Excel).
  def self.template_csv
    CSV.generate(+"\uFEFF", col_sep: ";") do |csv|
      csv << HEADER_NAMES.values
      csv << [ "SPECT", "GE", "Modèle A", "CAM", "Caméra 1", "SN-0001", "moyenne", "2024-03-15", "2024-04-01", "2027-04-01", "" ]
    end
  end

  def self.read_csv(content)
    text = content.to_s.dup.force_encoding(Encoding::UTF_8)
    unless text.valid_encoding?
      text = content.to_s.dup.force_encoding(Encoding::Windows_1252)
                    .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
    text = text.sub(/\A\uFEFF/, "")

    first_line = text.lines.first.to_s
    separator = SEPARATORS.max_by { |candidate| first_line.count(candidate) }
    separator = ";" if first_line.count(separator).zero?

    CSV.parse(text, col_sep: separator, liberal_parsing: true)
  end

  def self.read_xlsx(path)
    require "roo"
    book = Roo::Spreadsheet.open(path, extension: :xlsx)
    book.default_sheet = book.sheets.first
    return [] unless book.first_row

    (book.first_row..book.last_row).map { |index| book.row(index) }
  end

  # table : tableau de lignes, chaque ligne étant un tableau de cellules ;
  # la première ligne contient les en-têtes.
  def initialize(table, read_error: nil)
    @table = table
    @errors = []
    @rows = []
    @planned_locations = {}
    @planned_models = {}
    @seen_serials = {}

    if read_error
      add_error(nil, read_error)
    else
      analyze
    end
  end

  # ---------- Résultat de l'analyse ----------

  def valid?
    errors.empty? && rows.any?
  end

  # Locaux qui seraient créés : [{ department:, name:, code: }]
  def new_locations
    @planned_locations.values
  end

  # Modèles qui seraient créés : [{ manufacturer:, category:, name: }]
  def new_models
    @planned_models.values
  end

  # ---------- Validation de l'utilisateur ----------

  # Crée locaux, modèles et équipements dans une seule transaction.
  # Retourne les équipements créés, dans l'ordre du fichier.
  def commit!
    raise Invalid, "Le fichier contient des erreurs : rien n'a été importé." unless valid?

    ActiveRecord::Base.transaction do
      locations = @planned_locations.transform_values do |plan|
        Location.create!(department: plan[:department], name: plan[:name], code: plan[:code])
      end
      models = @planned_models.transform_values do |plan|
        EquipmentModel.create!(manufacturer: plan[:manufacturer], category: plan[:category], name: plan[:name])
      end

      rows.map do |row|
        Equipment.create!(
          equipment_model: row.model || models.fetch(row.model_key),
          location: row.location || locations.fetch(row.location_key),
          **row.attributes
        )
      end
    end
  end

  private

  def analyze
    header, *data = @table
    if header.blank? || header.all? { |cell| cell.to_s.strip.empty? }
      add_error(nil, "Le fichier est vide.")
      return
    end

    columns = header.map { |cell| HEADERS[normalize_header(cell)] }
    check_headers(header, columns)
    return if errors.any?

    load_reference_data
    data.each_with_index { |cells, index| analyze_row(index + 2, columns, cells) }
    add_error(nil, "Le fichier ne contient aucune ligne d'équipement.") if errors.empty? && rows.empty?
  end

  def check_headers(header, columns)
    header.each_with_index do |cell, index|
      next if cell.to_s.strip.empty? || columns[index]

      add_error(1, "colonne inconnue « #{cell.to_s.strip} »")
    end

    (REQUIRED - columns.compact).each do |key|
      add_error(1, "colonne obligatoire manquante « #{HEADER_NAMES[key]} »")
    end
  end

  def load_reference_data
    @categories = keyed(EquipmentCategory.kept, :name, :code_prefix)
    @manufacturers = keyed(Manufacturer.kept, :name, :code)
    @departments = keyed(Department.kept, :name, :code)
    @locations = Location.kept.group_by(&:department_id).transform_values { |list| keyed(list, :name, :code) }
    @models = EquipmentModel.kept.includes(:category).group_by(&:manufacturer_id).transform_values { |list| keyed(list, :name) }
    @existing_serials = Equipment.where.not(serial_number: nil).pluck(:equipment_model_id, :serial_number).to_set
  end

  def analyze_row(line, columns, cells)
    values = {}
    columns.each_with_index { |key, index| values[key] = clean(cells[index]) if key }
    return if values.values.all?(&:blank?)

    before = errors.size

    REQUIRED.each do |key|
      add_error(line, "#{HEADER_NAMES[key]} : valeur obligatoire") if values[key].blank?
    end
    return if errors.size > before

    category = @categories[normalize(values[:category])]
    add_error(line, "catégorie inconnue « #{values[:category]} » (à créer dans l'administration)") unless category
    manufacturer = @manufacturers[normalize(values[:manufacturer])]
    add_error(line, "fabricant inconnu « #{values[:manufacturer]} » (à créer dans l'administration)") unless manufacturer
    department = @departments[normalize(values[:department])]
    add_error(line, "département inconnu « #{values[:department]} » (à créer dans l'administration)") unless department
    return if errors.size > before

    model = @models.dig(manufacturer.id, normalize(values[:model]))
    model_key = [ manufacturer.id, normalize(values[:model]) ]
    if model && model.category_id != category.id
      add_error(line, "le modèle « #{values[:model]} » existe déjà avec une autre catégorie (#{model.category.name})")
    elsif model.nil?
      planned = @planned_models[model_key]
      if planned && planned[:category] != category
        add_error(line, "le modèle « #{values[:model]} » apparaît avec deux catégories différentes dans le fichier")
      end
    end

    location = @locations.dig(department.id, normalize(values[:location]))
    location_key = [ department.id, normalize(values[:location]) ]

    serial = values[:serial_number].presence
    check_serial(line, serial, model, model_key)
    criticality = parse_criticality(values[:criticality], line)
    acquired_on = parse_date(values[:acquired_on], line, "date_acquisition")
    commissioned_on = parse_date(values[:commissioned_on], line, "date_mise_en_service")
    warranty_ends_on = parse_date(values[:warranty_ends_on], line, "fin_garantie")
    return if errors.size > before

    @planned_models[model_key] ||= { manufacturer: manufacturer, category: category, name: values[:model] } unless model
    @planned_locations[location_key] ||= { department: department, name: values[:location], code: values[:location] } unless location

    rows << PlannedRow.new(
      line: line, model: model, model_key: model_key, location: location, location_key: location_key,
      attributes: {
        serial_number: serial, criticality: criticality, acquired_on: acquired_on,
        commissioned_on: commissioned_on, warranty_ends_on: warranty_ends_on,
        notes: values[:notes].presence
      }
    )
  end

  def check_serial(line, serial, model, model_key)
    return if serial.blank?

    if model && @existing_serials.include?([ model.id, serial ])
      add_error(line, "numéro de série « #{serial} » déjà enregistré pour ce modèle")
      return
    end

    key = [ model_key, serial ]
    if (first_line = @seen_serials[key])
      add_error(line, "numéro de série « #{serial} » en double dans le fichier (voir ligne #{first_line})")
    else
      @seen_serials[key] = line
    end
  end

  def parse_criticality(value, line)
    return "medium" if value.blank?

    CRITICALITIES[normalize(value)] || begin
      add_error(line, "criticité inconnue « #{value} » (faible, moyenne ou haute)")
      nil
    end
  end

  def parse_date(value, line, label)
    return if value.blank?
    return value if value.is_a?(Date)

    %w[%Y-%m-%d %d/%m/%Y].each do |format|
      return Date.strptime(value, format)
    rescue ArgumentError
      next
    end

    add_error(line, "#{label} : date invalide « #{value} » (format AAAA-MM-JJ ou JJ/MM/AAAA)")
    nil
  end

  # ---------- Utilitaires ----------

  def add_error(line, message)
    errors << Error.new(line, message)
  end

  def clean(cell)
    case cell
    when Date then cell
    when Time then cell.to_date
    when Float then cell == cell.to_i ? cell.to_i.to_s : cell.to_s
    else cell.to_s.strip
    end
  end

  def normalize(value)
    I18n.transliterate(value.to_s).downcase.strip.squeeze(" ")
  end

  def normalize_header(value)
    normalize(value).gsub(/[\s\-]+/, "_")
  end

  def keyed(records, *attributes)
    records.each_with_object({}) do |record, index|
      attributes.each { |attribute| index[normalize(record.public_send(attribute))] ||= record }
    end
  end
end
