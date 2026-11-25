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
- **Étape 6 : gestion des utilisateurs**
  - Création, modification et désactivation des comptes via la date de fin de validité.
  - Réinitialisation du mot de passe par e-mail (l'envoi reste à configurer en production).
- **Étape 7 : incidents et workflow de statuts**
  - Déclaration rapide, utilisable sur téléphone ; liste filtrée ; fiche avec historique des changements de statut (qui, quand, commentaire).
  - Workflow déclaré → qualifié → en cours → résolu → clôturé ; qualification exigeant une personne assignée active ; clôture exigeant une cause racine ; réouverture d'un incident résolu avec commentaire obligatoire.
  - Signalement des incidents de sécurité ou de radioprotection pouvant imposer une déclaration obligatoire.
  - Un incident critique qualifié passe l'équipement « en panne ».
  - Droits limités par département pour la déclaration (technicien, déclarant).
- **Étape 8 : interventions**
  - Interventions préventives, correctives, contrôles qualité, étalonnages et mises à jour logicielles, liées à un équipement et éventuellement à un incident.
  - Statuts planifiée → en cours → terminée, ou annulée ; une intervention terminée exige une date de fin et un rapport.
  - Coût saisi en euros et stocké en centimes ; durée d'indisponibilité en minutes.
  - Le statut de l'équipement suit les interventions en cours.
- **Étape 9 : documents techniques**
  - Documents rattachés à un équipement ou à un modèle, versionnés (une nouvelle version référence la précédente), téléchargeables.
  - Types, formats acceptés et taille limitée à 25 Mo ; date de validité, avec signalement des documents expirant dans les 60 jours.
- **Étape 10 : API v1** (premier lot)
  - Jetons personnels créés depuis l'interface web (menu « Jetons API »), expirables, révocables, stockés sous forme d'empreinte.
  - Endpoints : `GET /me`, équipements (liste, fiche), incidents (liste, fiche, création, transition), interventions (liste, fiche, création, démarrage, clôture, annulation).
  - Spécification OpenAPI (`openapi/v1.yaml`), servie sur `/api/v1/openapi.yaml`.
- **Tableau de bord** : état du parc, incidents ouverts par gravité, incidents urgents, interventions en cours, documents proches de l'expiration, tâches de l'utilisateur, calendrier mensuel des interventions.
- **Intégration continue** : GitHub Actions (Brakeman, bundler-audit, `importmap audit`, RuboCop, tests) ; script local `check.sh`.

#### Sécurité

- Un utilisateur non actif ne peut plus se connecter et ses jetons d'API sont refusés ; son historique est conservé.
- Garde-fou : le dernier administrateur actif ne peut être ni désactivé ni rétrogradé.

#### Modifié

- Certains champs sont figés après création, car ils entrent dans les codes ou lient les enregistrements : préfixe de type d'une catégorie, code court d'un fabricant, fabricant et catégorie d'un modèle, département d'un local, modèle d'un équipement.
- Écarts avec la spécification initiale : tables `manufacturers` et `equipment_code_counters` ajoutées ; colonne « code » supprimée de l'import (les codes sont toujours générés) ; départements inconnus refusés à l'import.
- Mises à jour des dépendances : Rails 8.1.4.1, roo 4.0, solid_queue 1.7.2 ; Ruby 3.4 (`.ruby-version`).

#### Corrigé

- À la résolution d'un incident critique, le statut de l'équipement est recalculé : « en maintenance » si une intervention est en cours, « en service » s'il ne reste aucun autre incident critique ouvert, sinon « en panne ». Rouvrir l'incident remet l'équipement « en panne ».

### À venir

- Étape 11 : page de consultation du journal d'audit (la politique d'accès existe déjà), sauvegardes planifiées avec restauration testée, mise en place sur le serveur, essais utilisateurs.
- Suite de l'API v1 : départements, locaux, catégories, modèles, documents, import, audit.
- Import du parc depuis l'interface web (aujourd'hui par tâches Rake).
- Politique de mot de passe et configuration de l'envoi d'e-mails avant la mise en service.
[Non publié]: <https://github.com/SalimBXL/nm-maintenance/compare/HEAD>
