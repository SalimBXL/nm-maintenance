require 'test_helper'

class EquipmentImportTest < ActiveSupport::TestCase
  HEADER = "categorie;fabricant;modele;departement;local;numero_serie\n".freeze

  setup do
    @department = Department.create!(name: 'Caméras', code: 'CAM')
    @location = Location.create!(department: @department, name: 'Caméra 1', code: 'CAM1')
    @spect = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    @petct = EquipmentCategory.create!(name: 'PET-CT', code_prefix: 'PETCT')
    @ge = Manufacturer.create!(name: 'GE', code: 'GE')
    @model = EquipmentModel.create!(manufacturer: @ge, category: @spect, name: 'Modèle A')
  end

  def import(*lines)
    EquipmentImport.from_csv("#{HEADER}#{lines.join("\n")}\n")
  end

  test 'un fichier valide crée les équipements avec des codes générés' do
    result = import('SPECT;GE;Modèle A;CAM;CAM1;SN-1')

    assert result.valid?
    assert_empty result.new_locations
    assert_empty result.new_models

    equipment = result.commit!.first
    assert_equal 'SPECT-GE-01', equipment.code
    assert_equal 'SN-1', equipment.serial_number
    assert_equal @location, equipment.location
  end

  test 'les valeurs sont reconnues sans tenir compte de la casse ni des accents' do
    result = import('spect;ge;modele a;cameras;camera 1;')

    assert result.valid?, result.errors.map(&:message).inspect
  end

  test 'les locaux et modèles inconnus sont proposés puis créés à la validation' do
    result = import('PET-CT;GE;Modèle C;CAM;CAM9;')

    assert result.valid?
    assert_equal 1, result.new_locations.size
    assert_equal 1, result.new_models.size

    assert_difference -> { Location.count } => 1, -> { EquipmentModel.count } => 1, -> { Equipment.count } => 1 do
      equipment = result.commit!.first
      assert_equal 'PETCT-GE-01', equipment.code
      assert_equal 'CAM9', equipment.location.code
    end
  end

  test 'une catégorie inconnue est une erreur à la bonne ligne' do
    result = import('SPECT;GE;Modèle A;CAM;CAM1;', 'SCAN;GE;Modèle A;CAM;CAM1;')

    assert_not result.valid?
    assert_equal [3], result.errors.map(&:line)
    assert_match(/catégorie inconnue/, result.errors.first.message)
  end

  test 'un département ou un fabricant inconnu est une erreur' do
    result = import('SPECT;GE;Modèle A;LABO;CAM1;', 'SPECT;ZZ;Modèle A;CAM;CAM1;')

    assert_equal [2, 3], result.errors.map(&:line)
    assert_match(/département inconnu/, result.errors.first.message)
    assert_match(/fabricant inconnu/, result.errors.last.message)
  end

  test 'une valeur obligatoire vide est une erreur' do
    result = import(';GE;Modèle A;CAM;CAM1;')

    assert_equal [2], result.errors.map(&:line)
    assert_match(/valeur obligatoire/, result.errors.first.message)
  end

  test 'un modèle existant ne peut pas changer de catégorie' do
    result = import('PET-CT;GE;Modèle A;CAM;CAM1;')

    assert_match(/autre catégorie/, result.errors.first.message)
  end

  test 'un numéro de série en double dans le fichier est une erreur' do
    result = import('SPECT;GE;Modèle A;CAM;CAM1;SN-1', 'SPECT;GE;Modèle A;CAM;CAM1;SN-1')

    assert_equal [3], result.errors.map(&:line)
    assert_match(/en double/, result.errors.first.message)
  end

  test 'un numéro de série déjà enregistré pour le modèle est une erreur' do
    Equipment.create!(equipment_model: @model, location: @location, serial_number: 'SN-1')
    result = import('SPECT;GE;Modèle A;CAM;CAM1;SN-1')

    assert_match(/déjà enregistré/, result.errors.first.message)
  end

  test "un fichier invalide n'importe rien" do
    result = import('SPECT;GE;Modèle A;CAM;CAM1;SN-1', 'SCAN;GE;Modèle A;CAM;CAM1;SN-2')

    assert_no_difference -> { Equipment.count } do
      assert_raises(EquipmentImport::Invalid) { result.commit! }
    end
  end

  test "une colonne inconnue ou manquante est signalée sur la ligne d'en-tête" do
    unknown = EquipmentImport.from_csv("categorie;fabricant;modele;departement;local;couleur\nSPECT;GE;Modèle A;CAM;CAM1;bleu\n")
    assert_match(/colonne inconnue/, unknown.errors.first.message)

    missing = EquipmentImport.from_csv("categorie;fabricant;modele;departement\nSPECT;GE;Modèle A;CAM\n")
    assert_match(/colonne obligatoire manquante « local »/, missing.errors.first.message)
  end

  test 'le séparateur virgule et le BOM UTF-8 sont acceptés' do
    result = EquipmentImport.from_csv("\uFEFFcategorie,fabricant,modele,departement,local\nSPECT,GE,Modèle A,CAM,CAM1\n")

    assert result.valid?, result.errors.map(&:message).inspect
  end

  test 'criticité et dates sont lues' do
    result = EquipmentImport.from_csv(
      "categorie;fabricant;modele;departement;local;criticite;date_acquisition\nSPECT;GE;Modèle A;CAM;CAM1;haute;15/03/2024\n"
    )
    equipment = result.commit!.first

    assert_equal 'high', equipment.criticality
    assert_equal Date.new(2024, 3, 15), equipment.acquired_on
  end

  test 'une criticité ou une date invalide est une erreur' do
    result = EquipmentImport.from_csv(
      "categorie;fabricant;modele;departement;local;criticite;date_acquisition\nSPECT;GE;Modèle A;CAM;CAM1;urgente;demain\n"
    )

    assert_equal 2, result.errors.size
  end

  test 'les lignes vides sont ignorées' do
    result = import('SPECT;GE;Modèle A;CAM;CAM1;SN-1', ';;;;;', '')

    assert result.valid?
    assert_equal 1, result.rows.size
  end

  test 'un fichier vide est une erreur' do
    assert_not EquipmentImport.from_csv('').valid?
    assert_not import.valid?
  end

  test 'le modèle de fichier fourni est valide' do
    assert EquipmentImport.from_csv(EquipmentImport.template_csv).valid?
  end
end
