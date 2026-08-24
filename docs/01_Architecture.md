# Architecture de N'MaShop

N'MaShop est développé en utilisant le framework **Flutter** (Dart), suivant une architecture modulaire et réactive basée sur **Riverpod** pour la gestion d'état et **Drift** pour la persistance locale via SQLite.

## Principes Architecturaux

L'application suit une structure "Feature-First" (par fonctionnalité). Chaque grand domaine fonctionnel possède son propre dossier dans `lib/features/`. 

```text
lib/
├── core/             # Éléments partagés (Thème, Base de données, Formatters, Widgets génériques)
├── features/         # Modules fonctionnels de l'application
│   ├── auth/         # Authentification et gestion de session
│   ├── dashboard/    # Tableau de bord principal (Métriques)
│   ├── stock/        # Gestion du catalogue de produits et inventaire
│   ├── sales/        # Module de facturation et de ventes
│   ├── caisse/       # Suivi des flux de trésorerie (Entrées/Sorties)
│   ├── settings/     # Configuration de la boutique, sauvegarde, exports
│   └── ...           
└── main.dart         # Point d'entrée de l'application
```

## Gestion de l'état (Riverpod)

L'état de l'application est géré exclusivement avec le package `flutter_riverpod`.
- Les fournisseurs (`Providers`) sont centralisés dans les dossiers `application/` de chaque feature (ex: `lib/features/sales/application/sales_providers.dart`).
- L'interface utilisateur réagit automatiquement aux changements d'état grâce aux `ConsumerWidget` ou `ConsumerStatefulWidget`.

## Navigation (GoRouter)

La navigation est déclarative, assurée par le package `go_router`. 
- Les routes sont définies dans `lib/core/router/app_router.dart`.
- La navigation protège les accès via des "guards" (redirection automatique si l'utilisateur n'est pas connecté).

## Design System

Le design system est basé sur les directives *Material 3* mais hautement personnalisé pour donner un rendu "Premium SaaS".
- **Thème dynamique :** Géré par `AppTheme` (`lib/core/theme/app_theme.dart`). Le mode sombre utilise une palette professionnelle "Midnight Blue".
- **Composants réutilisables :** Accessibles dans `lib/core/widgets/` (`AppCard`, `AppButton`, `AppPageHeader`, etc.).
