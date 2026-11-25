# Changelog

Toutes les modifications notables de ce projet sont consignées dans ce fichier.

Le format s'inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le projet suivra le [versionnage sémantique](https://semver.org/lang/fr/) à partir de la première version utilisable (fin du jalon 1).

Catégories utilisées : **Ajouté**, **Modifié**, **Corrigé**, **Supprimé**, **Sécurité**.

## [Non publié]

### Jalon 1 (MVP), en cours

#### Ajouté

- **Étape 1 : socle**
  - Squelette Rails, authentification par e-mail et mot de passe.
  - Journal d'audit (PaperTrail) activé sur les données métier : qui, quoi, quand, valeur avant et après.
  - Utilisateurs et quatre rôles : déclarant, technicien, responsable technique, administrateur.
  - Date de fin de validité optionnelle sur les utilisateurs : l'état actif est calculé, sans champ stocké.
  - Modèle de données du parc : départements, appartenances, locaux (avec référent optionnel), catégories, fabricants, modèles, équipements, historique des déplacements.
  - Code interne généré automatiquement au format `TYPE-FABRICANT-NN`, avec un compteur par couple (catégorie, fabricant).
- **Étape 2 : droits par rôle** (Pundit)
  - Matrice de droits par rôle sur les équipements, référentiels, départements, utilisateurs et journal d'audit.
  - Aucune suppression physique : archivage uniquement (`archived_at`).
- **Étape 3 : import du parc**
  - Import CSV ou Excel avec modèle de fichier fourni.
  - Contrôle avant import : erreurs signalées ligne par ligne, principe « tout ou rien ».
  - Création des locaux et modèles inconnus après validation de l'aperçu.
- **Étape 4 : interface web du parc**
  - Liste des équipements : recherche, filtres (département, catégorie, statut), archivés, pagination.
  - Fiche équipement avec historique des déplacements ; création, modification, archivage.
- **Étape 5 : administration des référentiels**
  - Gestion des départements, locaux, catégories, fabricants et modèles.
  - Un référentiel ne peut pas être archivé tant que des éléments actifs en dépendent.
- **Étape 6 : gestion des utilisateurs** (livrée, en attente de validation)
  - Création, modification et désactivation des comptes via la date de fin de validité.

#### Sécurité

- Un utilisateur non actif ne peut plus se connecter ; son historique est conservé.
- Garde-fou : le dernier administrateur actif ne peut être ni désactivé ni rétrogradé.

#### Modifié

- Certains champs sont figés après création, car ils entrent dans les codes ou lient les enregistrements : préfixe de type d'une catégorie, code court d'un fabricant, fabricant et catégorie d'un modèle, département d'un local, modèle d'un équipement.
- Écarts avec la spécification initiale : tables `manufacturers` et `equipment_code_counters` ajoutées ; colonne « code » supprimée de l'import (les codes sont toujours générés) ; départements inconnus refusés à l'import.

### À venir

- Étape 7 : incidents et workflow de statuts (déclaré, qualifié, en cours, résolu, clôturé).
- Étape 8 : interventions préventives et correctives.
- Étape 9 : documents techniques versionnés.
- Étape 10 : API v1, jetons personnels et spécification OpenAPI.
- Étape 11 : consultation de l'audit, sauvegardes, mise en place sur le serveur, essais utilisateurs.

[Non publié]: https://github.com/SalimBXL/nm-maintenance/compare/HEAD
