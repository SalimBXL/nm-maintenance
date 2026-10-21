# NM Maintenance

Application de gestion de maintenance d'équipements de **médecine nucléaire** : parc d'équipements, incidents, interventions, documents techniques et journal d'audit, avec une interface web et une API JSON versionnée.

> **État du projet : jalon 1 (MVP) en cours de réalisation.** Les étapes 1 à 5 sont installées et testées, la gestion des utilisateurs est livrée (en attente de validation). Les incidents, interventions, documents et l'API v1 restent à faire. Voir [Avancement](#avancement).

## Sommaire

- [Objectif](#objectif)
- [Fonctionnalités](#fonctionnalités)
- [Pile technique](#pile-technique)
- [Installation](#installation)
- [Import initial du parc](#import-initial-du-parc)
- [Règles de conception](#règles-de-conception)
- [Code interne des équipements](#code-interne-des-équipements)
- [Rôles et droits](#rôles-et-droits)
- [Modèle de données](#modèle-de-données)
- [API v1 (prévue)](#api-v1-prévue)
- [Avancement](#avancement)
- [Feuille de route](#feuille-de-route)
- [Points ouverts](#points-ouverts)

## Objectif

Fournir au service un outil utilisable au quotidien pour :

- renseigner et consulter le parc d'équipements, par département et par local ;
- déclarer et suivre les incidents, avec un workflow de statuts et son historique ;
- tracer les interventions préventives et correctives ;
- retrouver les documents techniques (manuels, certificats, etc.), versionnés ;
- garder une trace complète de toute modification (journal d'audit).

Contexte : un seul service, composé de plusieurs départements (laboratoires, caméras, salles d'injection, etc.). Aucune donnée existante à reprendre : le parc est saisi par import.

## Fonctionnalités

### Disponibles

- Départements, locaux, catégories d'équipements, fabricants et modèles (zone d'administration).
- Équipements : liste (recherche, filtres par département, catégorie et statut, archivés, pagination), fiche, création, modification, archivage, historique des déplacements.
- Code interne généré automatiquement (voir [ci-dessous](#code-interne-des-équipements)).
- Import du parc par fichier Excel ou CSV, avec aperçu et contrôle ligne par ligne.
- Utilisateurs, quatre rôles et droits par rôle ([Pundit](https://github.com/varvet/pundit)).
- Comptes à date de fin de validité, avec garde-fou sur le dernier administrateur actif.
- Journal d'audit sur les données métier ([PaperTrail](https://github.com/paper-trail-gem/paper_trail)).

### À venir (jalon 1)

- Incidents et workflow de statuts : **déclaré → qualifié → en cours → résolu → clôturé**.
- Interventions (préventives, correctives, contrôle qualité, étalonnage, mise à jour logicielle).
- Documents techniques versionnés, rattachés à un équipement ou à un modèle.
- Droits limités par département.
- Consultation du journal d'audit dans l'interface.
- API JSON `/api/v1` avec jetons personnels et spécification OpenAPI.
- Sauvegardes planifiées et mise en place sur le serveur.

### Hors du jalon 1

Client terminal (TUI) en Rust, application mobile, plans de maintenance récurrents, alertes et notifications par e-mail, contrôles qualité, radioprotection, contrats, pièces détachées, tableaux de bord (MTBF, MTTR, disponibilité), intégration à l'annuaire d'entreprise.

## Pile technique

| Besoin | Solution |
| --- | --- |
| Serveur, interface web, API | Ruby on Rails |
| Base de données | SQLite, sur le disque local du serveur, ouverte uniquement par Rails (mode WAL, clés étrangères activées) ; bascule possible vers PostgreSQL |
| Audit | `paper_trail` |
| Droits | `pundit` |
| Documents (à venir) | Active Storage, fichiers sur disque, références en base |
| Spécification d'API (à venir) | OpenAPI, par exemple via `rswag` |

Architecture : un serveur central porte toute la logique métier, l'audit et l'authentification. Les clients (web, puis terminal et mobile) ne parlent jamais directement à la base de données.

## Installation

### Prérequis

- Ruby et Bundler (version indiquée dans `.ruby-version` / `Gemfile`)
- SQLite 3

### Démarrage en local

```bash
git clone https://github.com/SalimBXL/nm-maintenance.git
cd nm-maintenance

bundle install
bin/rails db:setup      # crée la base, applique les migrations et les données initiales
bin/rails server
```

L'application est alors disponible sur <http://localhost:3000>.

### Tests

```bash
bin/rails test
```

### Déploiement

- Placer le fichier SQLite sur le **disque local** du serveur, jamais sur un partage réseau (verrouillage non fiable, mode WAL inutilisable, risque de corruption).
- Sauvegarder avec la commande de sauvegarde de SQLite (`.backup`), pas par simple copie du fichier en cours d'utilisation, et conserver une copie hors du serveur.
- Vérifier avec l'informatique l'hébergement, l'accès réseau et les sauvegardes.

## Import initial du parc

Fichier CSV ou Excel (première feuille uniquement) ; un modèle de fichier est fourni.

| Colonnes obligatoires | Colonnes facultatives |
| --- | --- |
| catégorie, fabricant, modèle, département, local | numéro de série, criticité, date d'acquisition, date de mise en service, fin de garantie, notes |

- Il n'y a **pas de colonne « code »** : le code interne est toujours généré.
- Les valeurs sont reconnues sans tenir compte de la casse ni des accents, par nom ou par code.
- Les **locaux et modèles inconnus** sont proposés à la création dans l'aperçu, puis créés à la validation.
- Les **départements, catégories et fabricants inconnus** provoquent une erreur : ils doivent d'abord être créés dans l'administration.
- **Tout ou rien** : si une seule ligne est invalide, rien n'est importé, et les erreurs sont indiquées ligne par ligne.

## Règles de conception

- **Pas de suppression physique** : colonne `archived_at` sur les tables principales. Un référentiel ne s'archive pas tant que des éléments actifs en dépendent.
- Clés étrangères et index dès le départ ; contraintes d'unicité (code interne, n° de série par modèle).
- Montants en centimes (entiers), dates en UTC.
- Statuts en énumérations stockées en texte, partagées entre l'API et les clients.
- Aucune fonction propre à SQLite, pour garder un passage à PostgreSQL transparent.
- Noms de tables et de colonnes en anglais (convention Rails) ; libellés affichés en français via l'internationalisation.
- Certains champs sont figés après création car ils entrent dans les codes ou lient les enregistrements : préfixe de type d'une catégorie, code court d'un fabricant, fabricant et catégorie d'un modèle, département d'un local, modèle d'un équipement.

## Code interne des équipements

Format **`TYPE-FABRICANT-NN`**, par exemple `PETCT-GE-01` ou `SPECT-SIEM-02`.

- Le préfixe de type vient de la catégorie (8 caractères au plus, sans tiret : PET-CT devient `PETCT`), le code court du fabricant d'une liste de référence gérée dans l'application.
- Compteur séquentiel **par couple (catégorie, fabricant)** : le premier SPECT Siemens est `SPECT-SIEM-01`, même si `SPECT-GE-01` existe.
- Généré à la création, jamais modifié, jamais réutilisé, même après archivage ou mise hors service.
- Il ne contient ni département ni local, car un équipement peut être déplacé. Le numéro de série du fabricant reste un champ séparé.

| Catégorie | Préfixe | Fabricant | Code |
| --- | --- | --- | --- |
| PET-CT | PETCT | GE | GE |
| SPECT | SPECT | Veenstra Instruments (gamme VIK) | VIK |
| SPECT-CT | SPECTCT | Comecer | COME |
| Activimètre | ACT | Trasis | TRAS |
| Distributeur d'activité | DIST | | |
| Unidose | UNID | | |

Ces listes sont configurables dans l'application.

## Rôles et droits

| Rôle | Peut faire |
| --- | --- |
| Administrateur | Configurer, gérer les utilisateurs, tout consulter et modifier |
| Responsable technique | Gérer le parc, qualifier et clôturer les incidents, planifier et valider les interventions |
| Technicien | Intervenir, saisir les rapports, mettre à jour les incidents qui lui sont assignés |
| Déclarant | Déclarer un incident, suivre son statut, consulter les fiches équipements |

Droits actuellement en place :

| Ressource | Administrateur | Responsable technique | Technicien | Déclarant |
| --- | --- | --- | --- | --- |
| Équipements, locaux, catégories, modèles, fabricants | lire, créer, modifier, archiver | lire, créer, modifier, archiver | lire | lire |
| Départements | lire, créer, modifier, archiver | lire | lire | lire |
| Utilisateurs | tout | sa propre fiche | sa propre fiche | sa propre fiche |
| Journal d'audit | lire | lire | – | – |

Personne ne peut supprimer physiquement. La limitation par département (technicien, déclarant) sera appliquée avec les incidents et les interventions.

**Comptes** : un utilisateur est non actif si sa date de fin de validité est antérieure à la date du jour (fuseau horaire du service) ; le compte reste actif le jour même. Aucun champ « actif » n'est stocké. Un utilisateur non actif ne peut plus se connecter, son historique est conservé. Il est impossible de retirer le rôle ou de désactiver le dernier administrateur actif.

## Modèle de données

**Réalisé** : `users`, `departments`, `department_memberships`, `locations`, `equipment_categories`, `manufacturers`, `equipment_models`, `equipments`, `equipment_moves`, `equipment_code_counters`, `versions` (audit).

**À réaliser** : `incidents`, `incident_status_changes`, `events` (interventions), `documents`.

### Gravité des incidents (décidé)

| Niveau | Définition | Prise en charge visée |
| --- | --- | --- |
| Critique | Équipement indisponible sans solution de repli, ou risque pour un patient ou le personnel | Quelques heures |
| Majeure | Fonctionnement dégradé ou solution de contournement, examens perturbés | Dans la journée |
| Mineure | Gêne sans impact sur l'activité ni sur la sécurité | Quelques jours ouvrés |

Le déclarant propose une gravité, le responsable technique la confirme à la qualification. La dimension réglementaire est portée par le champ *nature* (technique, sécurité, radioprotection), pas par la gravité.

## API v1 (prévue)

- Préfixe `/api/v1`, format JSON, authentification par jeton personnel (`Authorization: Bearer ...`) généré depuis l'interface web.
- Pagination, filtres, format d'erreur unique, droits identiques à ceux de l'interface web.
- Spécification OpenAPI maintenue à partir des tests.

Premier lot à stabiliser (il servira au futur client terminal) : `GET /me`, équipements (liste et fiche), création d'incident, interventions (création et clôture).

## Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | Squelette Rails, authentification, audit, modèle de données du parc, utilisateurs et rôles, code interne | Installée, tests validés |
| 2 | Droits par rôle (Pundit) | Installée, tests validés |
| 3 | Import du parc par Excel ou CSV | Installée, parc importé |
| 4 | Interface web du parc | Installée, tests validés |
| 5 | Administration des référentiels | Installée, tests validés |
| 6 | Gestion des utilisateurs | Livrée, en attente de validation |
| 7 | Incidents et workflow de statuts | À faire |
| 8 | Interventions | À faire |
| 9 | Documents techniques | À faire |
| 10 | API v1, jetons personnels, OpenAPI | À faire |
| 11 | Consultation de l'audit, sauvegardes, mise en place sur le serveur, essais utilisateurs | À faire |

### Critères d'acceptation du jalon 1

- Tout le parc du service est saisi et consultable par département et local.
- Un déclarant peut signaler un incident en moins d'une minute et en suivre le statut.
- Chaque changement de statut d'incident et chaque modification de données apparaît dans l'audit.
- Un technicien peut saisir et clôturer une intervention liée à un incident.
- Les documents sont retrouvables par équipement, modèle ou type, avec leur historique de versions.
- L'API est documentée (OpenAPI) et les endpoints prioritaires sont couverts par des tests.
- Une sauvegarde de la base est planifiée et sa restauration a été testée.

## Feuille de route

- **Jalon 1 (MVP)** : serveur Rails, interface web, API v1, parc, incidents, interventions, documents, audit.
- **Jalon 2** : client terminal (TUI) en Rust pour les postes sans navigateur, planification du préventif, alertes et notifications, tableaux de bord.
- **Jalon 3** : contrôles qualité, radioprotection, contrats, pièces détachées, PWA puis éventuellement application Flutter, intégrations (annuaire d'entreprise).

## Points ouverts

- Serveur interne et contraintes de l'informatique (hébergement, accès réseau, sauvegardes).
- Réglementation applicable aux incidents de radioprotection et à leur déclaration, selon le pays.
- Niveaux de criticité des équipements : faible, moyenne, haute (hypothèse à confirmer).
- Limitation des droits par département : lecture ou seulement actions, à préciser avec les incidents.
- Politique de mot de passe et envoi d'e-mails de réinitialisation, à prévoir avant la mise en service.
- Mobile : PWA, Flutter, ou rien dans un premier temps.

## Documentation

Les décisions et spécifications détaillées se trouvent dans les documents de travail du projet : « Décisions et recommandations », « Spécification du jalon 1 (MVP) » et « Jalon 1 : synthèse et état d'avancement ».

## Licence

À définir.
