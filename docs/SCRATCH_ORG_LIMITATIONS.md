// File: docs/SCRATCH_ORG_LIMITATIONS.md
# Scratch Org Limitations pour FoxSec

## Features Non Disponibles en Scratch Org

### SecuritySettings (Feature)
- **Statut** : NON disponible comme feature scratch org
- **Impact** : Certains audits de sécurité avancés nécessitent une org de production/sandbox
- **Workaround** : Utiliser les `securitySettings` dans la section `settings` du scratch-def
- **Alternative** : Tester les audits de sécurité dans une sandbox ou Developer Edition persistante

### Agentforce
- **Statut** : NON disponible en scratch org (Q1 2026)
- **Impact** : Les fonctionnalités d'automatisation via Agentforce doivent être testées en sandbox
- **Workaround** : Développer avec des Invocable Actions compatibles, tester Agentforce en sandbox
- **Alternative** : Utiliser Flow Builder pour les tests initiaux

## Objets Setup Limités

Certains objets de métadonnées ne sont pas accessibles via SOQL en scratch org :
- `SetupAuditTrail` (historique setup limité)
- Certaines vues de `PermissionSet` avancées
- `LoginHistory` (données limitées)

## Stratégie de Test

1. **Scratch Org** : Tests unitaires, logique core, UI
2. **Developer Edition** : Tests d'intégration, audits sécurité complets
3. **Sandbox** : Tests E2E, Agentforce, limites de performances
4. **Production** : Validation finale avant release AppExchange

## Features Valides Utilisées
```json
"features": [
  "LightningServiceConsole",  // Console Lightning
  "Communities",               // Pour tests multi-utilisateurs
  "ServiceCloud",              // Objets Case, etc.
  "API",                       // Accès API REST/SOAP
  "AuthorApex"                 // Création de classes Apex
]
```

## Settings de Sécurité Disponibles

Les paramètres suivants SONT configurables via `settings.securitySettings`:
- Password policies
- Session settings
- Network access (IP ranges)
- Login hours
- Certificate/identity settings

**Note** : Ces settings ne donnent PAS accès à tous les objets Setup Metadata.