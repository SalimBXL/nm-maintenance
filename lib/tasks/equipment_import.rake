# À placer dans lib/tasks/ de l'application Rails.
#
#   bin/rails equipment:preview FILE=parc.xlsx   # analyse seulement, ne crée rien
#   bin/rails equipment:import  FILE=parc.xlsx   # importe (tout ou rien)
#
# Sur le serveur : RAILS_ENV=production bin/rails equipment:import FILE=parc.xlsx
module EquipmentImportTask
  module_function

  def load(path)
    abort("Indiquez le fichier : FILE=chemin/vers/fichier.xlsx") if path.to_s.empty?
    abort("Fichier introuvable : #{path}") unless File.exist?(path)

    if path.downcase.end_with?(".xlsx")
      EquipmentImport.from_xlsx(path)
    else
      EquipmentImport.from_csv(File.binread(path))
    end
  end

  def report(import)
    if import.errors.any?
      puts "#{import.errors.size} erreur(s) :"
      import.errors.each do |error|
        where = error.line ? "Ligne #{error.line}" : "Fichier"
        puts "  #{where} : #{error.message}"
      end
      puts
    end

    puts "#{import.rows.size} équipement(s) valide(s)."

    if import.new_locations.any?
      puts "\nLocaux qui seront créés (#{import.new_locations.size}) :"
      import.new_locations.each { |plan| puts "  - #{plan[:department].name} / #{plan[:name]}" }
    end

    if import.new_models.any?
      puts "\nModèles qui seront créés (#{import.new_models.size}) :"
      import.new_models.each { |plan| puts "  - #{plan[:manufacturer].name} / #{plan[:name]} (#{plan[:category].name})" }
    end
  end
end

namespace :equipment do
  desc "Analyse un fichier d'import du parc (CSV ou .xlsx) sans rien créer : FILE=chemin"
  task preview: :environment do
    import = EquipmentImportTask.load(ENV["FILE"])
    EquipmentImportTask.report(import)
    puts(import.valid? ? "\nLe fichier est valide : vous pouvez lancer equipment:import." : "\nLe fichier n'est pas valide : corrigez-le puis relancez l'analyse.")
  end

  desc "Importe le parc depuis un fichier CSV ou .xlsx (tout ou rien) : FILE=chemin"
  task import: :environment do
    import = EquipmentImportTask.load(ENV["FILE"])
    EquipmentImportTask.report(import)
    abort("\nFichier invalide : rien n'a été importé.") unless import.valid?

    # Auteur indiqué dans le journal d'audit
    PaperTrail.request.whodunnit = ENV.fetch("WHODUNNIT", "import du parc")

    created = import.commit!
    puts "\n#{created.size} équipement(s) créé(s) :"
    created.each { |equipment| puts "  #{equipment.code}  #{equipment.serial_number}" }
  end
end
