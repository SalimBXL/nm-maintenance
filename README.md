# NM Maintenance

Application de gestion de maintenance d'équipements de **médecine nucléaire** : parc d'équipements, incidents, interventions, documents techniques et journal d'audit, avec une interface web et une API JSON versionnée.

> **État : jalon 1 (MVP) bien avancé.** Le parc, les incidents, les interventions, les documents, le tableau de bord, les jetons d'API et le premier lot de l'API v1 sont en place. Restent notamment la consultation du journal d'audit dans l'interface, les sauvegardes et la mise en service. Voir [Avancement](#avancement).

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Pile technique](#pile-technique)
- [Démarrage](#démarrage)
- [Import du parc](#import-du-parc)
- [Code interne des équipements](#code-interne-des-équipements)
- [Rôles et droits](#rôles-et-droits)
- [Incidents et interventions](#incidents-et-interventions)
- [Documents techniques](#documents-techniques)
- [API v1](#api-v1)
- [Principes de conception](#principes-de-conception)
- [Qualité et intégration continue](#qualité-et-intégration-continue)
- [Déploiement](#déploiement)
- [Avancement](#avancement)
- [Feuille de route](#feuille-de-route)
- [Points ouverts](#points-ouverts)

## Fonctionnalités

Contexte : un seul service, composé de plusieurs départements (laboratoires, caméras, salles d'injection, etc.), sans donnée existante à reprendre.

| Domaine | Contenu |
| --- | --- |
| Tableau de bord | Page d'accueil : état du parc, incidents ouverts par gravité, incidents urgents, interventions en cours, documents proches de l'expiration, tâches de l'utilisateur, calendrier mensuel des interventions |
| Parc | Départements, locaux, catégories, fabricants, modèles, équipements ; recherche, filtres (département, catégorie, statut), archivage, historique des déplacements |
| Incidents | Déclaration rapide (utilisable sur téléphone), workflow de statuts avec historique, liste filtrée, fiche |
| Interventions | Préventives, correctives, contrôles qualité, étalonnages, mises à jour logicielles ; liées à un équipement et éventuellement à un incident |
| Documents | Documents techniques versionnés, rattachés à un équipement ou à un modèle, téléchargeables |
| Utilisateurs | Quatre rôles, comptes à date de fin de validité, réinitialisation de mot de passe |
| API | `/api/v1` en JSON, jetons personnels, spécification OpenAPI |
| Audit | Toute création, modification ou archivage de données métier est journalisé (auteur, date, valeurs avant et après) |

## Pile technique

| Besoin | Solution |
| --- | --- |
| Langage et framework | Ruby 3.4.2, Rails 8.1 |
| Interface web | Rails, Hotwire (Turbo, Stimulus), import maps, Propshaft |
| Base de données | SQLite, dans `storage/`, ouverte uniquement par Rails ; migrations compatibles PostgreSQL |
| Audit | `paper_trail` |
| Droits | `pundit` |
| Import Excel | `roo` |
| Fichiers | Active Storage (disque local) |
| Tâches et cache | Solid Queue, Solid Cache, Solid Cable |
| Déploiement | Docker, Kamal |

Architecture : un serveur central porte toute la logique métier, l'audit et l'authentification. Les clients (web, puis terminal et mobile) ne parlent jamais directement à la base de données.

## Démarrage

### Prérequis

- Ruby 3.4.2 (voir `.ruby-version`) et Bundler
- SQLite 3
- libvips (variantes d'images Active Storage)

### Installation

```bash
git clone https://github.com/SalimBXL/nm-maintenance.git
cd nm-maintenance
bundle install
```

Pour créer le premier administrateur, fournissez `ADMIN_EMAIL` et `ADMIN_PASSWORD` avant d'initialiser la base. En développement, placez-les dans un fichier `.env` (chargé par `dotenv`) ; `ADMIN_NAME` est facultatif. Aucun mot de passe par défaut n'existe dans le code.

```bash
# .env (ne pas versionner)
ADMIN_EMAIL=admin@exemple.org
ADMIN_PASSWORD=un-mot-de-passe-d-au-moins-12-caracteres
```

```bash
bin/rails db:setup     # crée la base, applique les migrations et les données de référence
bin/rails server
```

L'application est disponible sur <http://localhost:3000>. Les données de référence (`db/seeds.rb`) sont rejouables sans doublon : catégories (PET-CT, SPECT, SPECT-CT, Activimètre, Distributeur d'activité, Unidose) et fabricants (GE, Veenstra Instruments, Comecer, Trasis).

### Tests

```bash
bin/rails test
```

## Import du parc

L'import se fait aujourd'hui par **tâches Rake**, à partir d'un fichier CSV ou `.xlsx` (première feuille uniquement) :

```bash
bin/rails equipment:preview FILE=parc.xlsx   # analyse seulement, ne crée rien
bin/rails equipment:import  FILE=parc.xlsx   # importe (tout ou rien)

# En production
RAILS_ENV=production bin/rails equipment:import FILE=parc.xlsx
```

L'auteur inscrit dans le journal d'audit est « import du parc », modifiable avec la variable `WHODUNNIT`.

| Colonnes obligatoires | Colonnes facultatives |
| --- | --- |
| catégorie, fabricant, modèle, département, local | numéro de série, criticité, date d'acquisition, date de mise en service, fin de garantie, notes |

- Pas de colonne « code » : le code interne est toujours généré.
- Valeurs reconnues sans tenir compte de la casse ni des accents, par nom ou par code.
- Locaux et modèles inconnus : listés par l'analyse, puis créés à l'import.
- Départements, catégories et fabricants inconnus : erreur, à créer d'abord dans l'administration.
- Tout ou rien : si une ligne est invalide, rien n'est importé ; les erreurs sont indiquées ligne par ligne.

## Code interne des équipements

Format **`TYPE-FABRICANT-NN`**, par exemple `PETCT-GE-01` ou `SPECTCT-GE-01`.

- Préfixe de type issu de la catégorie (8 caractères au plus, sans tiret), code court issu du fabricant.
- Compteur séquentiel **par couple (catégorie, fabricant)** : le premier SPECT Siemens serait `SPECT-SIEM-01`, même si `SPECT-GE-01` existe.
- Généré à la création, jamais modifié, jamais réutilisé, même après archivage ou mise hors service.
- Il ne contient ni département ni local, car un équipement peut être déplacé. Le numéro de série reste un champ séparé.

## Rôles et droits

| Rôle | Rôle dans l'application |
| --- | --- |
| Administrateur | Configure, gère les utilisateurs, tout consulter et modifier |
| Responsable technique | Gère le parc, qualifie et clôture les incidents, planifie et valide les interventions, consulte l'audit |
| Technicien | Intervient, met à jour les incidents qui lui sont assignés, saisit les rapports |
| Déclarant | Déclare des incidents, suit leur statut, consulte les fiches |

| Ressource | Administrateur | Responsable technique | Technicien | Déclarant |
| --- | --- | --- | --- | --- |
| Équipements, locaux, catégories, modèles, fabricants | tout sauf suppression | tout sauf suppression | lecture | lecture |
| Départements | tout sauf suppression | lecture | lecture | lecture |
| Utilisateurs | tout | sa propre fiche | sa propre fiche | sa propre fiche |
| Incidents | déclarer, modifier, tout le workflow | déclarer, modifier, tout le workflow | déclarer dans ses départements ; passer ses incidents assignés en cours ou résolu | déclarer dans ses départements |
| Interventions | créer, modifier, tout le workflow | créer, modifier, tout le workflow | créer pour ses incidents assignés ; démarrer, terminer les siennes | lecture |
| Documents | créer, modifier, versionner, archiver | créer, modifier, versionner, archiver | lecture, téléchargement | lecture, téléchargement |
| Jetons d'API | les siens | les siens | les siens | les siens |
| Journal d'audit | lecture | lecture | – | – |

Personne ne peut supprimer physiquement. Un utilisateur non connecté ou non actif n'a aucun droit.

**Comptes** : un utilisateur est non actif si sa date de fin de validité est antérieure à la date du jour (fuseau horaire du service) ; le compte reste actif le jour même. Aucun champ « actif » n'est stocké. Un utilisateur non actif ne peut plus se connecter et ses jetons d'API sont refusés ; son historique est conservé. Le dernier administrateur actif ne peut être ni désactivé ni rétrogradé.

## Incidents et interventions

### Incidents

Statuts : **déclaré → qualifié → en cours → résolu → clôturé**. Un incident résolu peut être rouvert (remis en cours) avec un commentaire obligatoire.

- Chaque changement de statut est enregistré (qui, quand, commentaire).
- La qualification exige une personne assignée, active et autre qu'un déclarant.
- La clôture exige une cause racine.
- Les incidents de nature sécurité ou radioprotection sont signalés comme pouvant imposer une déclaration obligatoire.
- Un incident critique qualifié passe l'équipement « en panne ».
- On ne peut pas déclarer d'incident sur un équipement archivé.

| Gravité | Définition | Prise en charge visée |
| --- | --- | --- |
| Critique | Équipement indisponible sans solution de repli, ou risque pour un patient ou le personnel | Quelques heures |
| Majeure | Fonctionnement dégradé ou contournement possible, examens perturbés | Dans la journée |
| Mineure | Gêne sans impact sur l'activité ni sur la sécurité | Quelques jours ouvrés |

Le déclarant propose une gravité, le responsable technique la confirme à la qualification. La dimension réglementaire est portée par le champ *nature* (technique, sécurité, radioprotection).

### Interventions

Statuts : **planifiée → en cours → terminée**, ou annulée. Une intervention peut être terminée directement.

- Une intervention terminée exige une date de fin et un rapport.
- Le coût est saisi en euros et stocké en centimes ; la durée d'indisponibilité est en minutes.
- Le statut de l'équipement suit les interventions : « en maintenance » tant qu'une intervention est en cours, puis retour « en service », ou « en panne » si un incident critique qualifié ou en cours n'est pas résolu. Un équipement en panne ou hors service n'est jamais modifié au démarrage.

## Documents techniques

- Rattachés **soit** à un équipement, **soit** à un modèle d'équipement, jamais aux deux.
- Types : manuel, certificat, déclaration de conformité, rapport, procédure, autre.
- Formats acceptés : PDF, PNG, JPEG, texte, ZIP, Word et Excel ; 25 Mo au maximum.
- Une nouvelle version référence la précédente ; l'historique reste consultable.
- Une date de validité est enregistrée ; les documents expirant dans les 60 jours sont signalés.

## API v1

- Préfixe `/api/v1`, JSON.
- Authentification par **jeton personnel** (`Authorization: Bearer mt_...`), créé depuis l'interface web (menu « Jetons API »). Le jeton expire (365 jours par défaut), peut être révoqué et n'est jamais stocké en clair (seule son empreinte l'est).
- Droits identiques à ceux de l'interface web.
- Pagination `page` / `per_page` (25 par défaut, 100 au maximum), format d'erreur unique `{ "error": { "code", "message", "details" } }`, dates ISO 8601.
- Spécification OpenAPI : [`openapi/v1.yaml`](openapi/v1.yaml), servie sans authentification sur `/api/v1/openapi.yaml`.

| Ressource | Endpoints |
| --- | --- |
| Utilisateur courant | `GET /me` |
| Équipements | `GET /equipments`, `GET /equipments/:id` |
| Incidents | `GET /incidents`, `GET /incidents/:id`, `POST /incidents`, `POST /incidents/:id/transition` |
| Interventions | `GET /events`, `GET /events/:id`, `POST /events`, `POST /events/:id/start`, `POST /events/:id/complete`, `POST /events/:id/cancel` |

Exemple :

```bash
curl -H "Authorization: Bearer mt_xxxxxxxx" http://localhost:3000/api/v1/me
```

Ce premier lot, destiné au futur client terminal, est stabilisé en priorité. Départements, locaux, catégories, modèles, documents, import et audit viendront ensuite.

## Principes de conception

- **Pas de suppression physique** : colonne `archived_at` sur les tables principales. Un référentiel ne s'archive pas tant que des éléments actifs en dépendent.
- Clés étrangères et index dès le départ ; contraintes d'unicité (code interne, numéro de série par modèle).
- Montants en centimes (entiers), dates en UTC.
- Statuts en énumérations stockées en texte, lisibles dans la base et portables vers PostgreSQL.
- Aucune fonction propre à SQLite.
- Noms de tables et de colonnes en anglais (convention Rails) ; libellés affichés en français via l'internationalisation.
- Certains champs sont figés après création car ils entrent dans les codes ou lient les enregistrements : préfixe d'une catégorie, code court d'un fabricant, fabricant et catégorie d'un modèle, département d'un local, modèle d'un équipement.

## Qualité et intégration continue

Le workflow GitHub Actions (`.github/workflows/ci.yml`) exécute à chaque pull request et à chaque push sur `main` :

- Brakeman (analyse de sécurité du code) et bundler-audit (vulnérabilités des gems) ;
- `importmap audit` (dépendances JavaScript) ;
- RuboCop (style) ;
- la suite de tests (`bin/rails db:test:prepare test`).

En local, `check.sh` lance RuboCop (avec correction automatique) puis les tests.

## Déploiement

Une image Docker de production (`Dockerfile`) et une configuration Kamal (`config/deploy.yml`) sont fournies ; les valeurs par défaut (adresse du serveur, registre) sont des exemples à remplacer.

- En production, les bases SQLite (principale, cache, file d'attente, cable) et les fichiers Active Storage vivent dans `storage/`, à monter sur un **volume persistant du disque local** du serveur, jamais sur un partage réseau (verrouillage non fiable, risque de corruption).
- Fournir `RAILS_MASTER_KEY` et, pour la création du premier administrateur, `ADMIN_EMAIL` et `ADMIN_PASSWORD` dans les variables d'environnement du service.
- Sauvegarder la base avec la commande de sauvegarde de SQLite (`.backup`), pas par simple copie du fichier en cours d'utilisation, et conserver une copie hors du serveur. Tester la restauration.
- Vérifier avec l'informatique l'hébergement, l'accès réseau et les sauvegardes.

## Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | Squelette Rails, authentification, audit, modèle de données du parc, code interne | Fait |
| 2 | Droits par rôle (Pundit) | Fait |
| 3 | Import du parc (CSV, Excel) | Fait (tâches Rake) |
| 4 | Interface web du parc | Fait |
| 5 | Administration des référentiels | Fait |
| 6 | Gestion des utilisateurs | Fait |
| 7 | Incidents et workflow de statuts | Fait |
| 8 | Interventions | Fait |
| 9 | Documents techniques | Fait |
| 10 | API v1, jetons personnels, OpenAPI | Premier lot fait (utilisateur, équipements, incidents, interventions) |
| 11 | Consultation de l'audit, sauvegardes, mise en service, essais utilisateurs | À faire |

Reste à faire pour le jalon 1 : interface de consultation du journal d'audit (la politique d'accès existe, pas encore de page), sauvegardes planifiées et restauration testée, mise en place sur le serveur, essais avec quelques utilisateurs, et le reste de l'API (documents, référentiels, import, audit).

### Critères d'acceptation du jalon 1

- Tout le parc du service est saisi et consultable par département et local.
- Un déclarant peut signaler un incident en moins d'une minute et en suivre le statut.
- Chaque changement de statut d'incident et chaque modification de données apparaît dans l'audit.
- Un technicien peut saisir et clôturer une intervention liée à un incident.
- Les documents sont retrouvables par équipement, modèle ou type, avec leur historique de versions.
- L'API est documentée (OpenAPI) et les endpoints prioritaires sont couverts par des tests.
- Une sauvegarde de la base est planifiée et sa restauration a été testée.

## Feuille de route

- **Jalon 1 (MVP)** : en cours de finalisation (voir ci-dessus).
- **Jalon 2** : client terminal (TUI) en Rust pour les postes sans navigateur, planification du préventif, alertes et notifications par e-mail, indicateurs (MTBF, MTTR, disponibilité).
- **Jalon 3** : contrôles qualité, radioprotection, contrats, pièces détachées, PWA puis éventuellement application Flutter, intégration à l'annuaire d'entreprise.

## Points ouverts

- Serveur interne et contraintes de l'informatique (hébergement, accès réseau, sauvegardes).
- Réglementation applicable aux incidents de radioprotection et à leur déclaration, selon le pays.
- Niveaux de criticité des équipements : faible, moyenne, haute (hypothèse à confirmer).
- Politique de mot de passe (longueur minimale) à fixer avant la mise en service ; l'envoi d'e-mails de réinitialisation doit être configuré.
- Mobile : PWA, Flutter, ou rien dans un premier temps.

## Licence

À définir.
