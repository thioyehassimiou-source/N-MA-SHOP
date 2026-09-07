# Rapports d'audit N'MaShop

Ce dossier consigne l'audit architectural complet de N'MaShop et les décisions
qui en découlent. **Ces documents font foi pour tout le développement** : chaque
nouvelle contribution doit s'y conformer.

## Table des documents

| # | Document | Objet |
|---|----------|-------|
| 1 | [01-rapport-global.md](01-rapport-global.md) | Audit global : structure, architecture, flux, DB, état, dette, perf, sécurité |
| 2 | [02-adr.md](02-adr.md) | Journal des décisions d'architecture (ADR-001 → ADR-004) |
| 3 | [03-roadmap.md](03-roadmap.md) | Feuille de route V1.0 → V2.0 et jalons |
| 4 | [04-conventions.md](04-conventions.md) | Standards de code, nommage, commits, docstrings |
| 5 | [05-architecture-technique.md](05-architecture-technique.md) | Couches, matrice des dépendances, règles d'import |

## Règles directrices (rappel)

1. **Clean Architecture simplifiée** sur tous les modules (ADR-002). L'UI ne
   touche jamais Drift directement.
2. **Offline-first** : la base SQLite locale est la source de vérité unique (ADR-001).
3. **Riverpod** est l'unique brique d'état + injection (ADR-003).
4. **Pas d'IA** dans le MVP (ADR-004).
5. Jalon en cours : **V1.0 — Assainissement et harmonisation comptable**.
