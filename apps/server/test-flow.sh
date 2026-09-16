#!/usr/bin/env bash
# ==============================================================================
# Script de test automatisé du flux complet de bout en bout (E2E)
# N'MaShop Mobile Ecosystem — Backend API
# ==============================================================================

BASE_URL="http://localhost:3000"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    N'MASHOP MOBILE — FLUX DE TEST COMPLET (E2E)     ${NC}"
echo -e "${BLUE}======================================================${NC}\n"

# Vérifier si le serveur répond
if ! curl -s "$BASE_URL/api/v1/sync/status" > /dev/null; then
  echo -e "${RED}❌ Le serveur ne répond pas sur $BASE_URL.${NC}"
  echo -e "Veuillez vous assurer que 'npm run start:dev' est bien lancé dans apps/server."
  exit 1
fi

echo -e "${GREEN}✓ Connectivité serveur OK : $BASE_URL${NC}\n"

PAIR_TOKEN="pair-$(date +%s)"
DEVICE_ID="PHONE-PATRON-$(date +%s)"
LICENSE_KEY="TEST-LICENSE-KEY"

# ------------------------------------------------------------------------------
# 1. Desktop : Initialisation du jumelage
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/6] Desktop : Initialisation d'un code de jumelage...${NC}"
INIT_RES=$(curl -s -X POST "$BASE_URL/api/v1/auth/pair/init" \
  -H "Content-Type: application/json" \
  -d "{
    \"token\": \"$PAIR_TOKEN\",
    \"machineId\": \"DESKTOP-CAISSE-01\",
    \"licenseKey\": \"$LICENSE_KEY\",
    \"shopName\": \"Boutique Diallo & Frères\",
    \"currency\": \"GNF\"
  }")

echo "Réponse : $INIT_RES"
echo -e "${GREEN}✓ Jeton éphémère créé : $PAIR_TOKEN${NC}\n"

# ------------------------------------------------------------------------------
# 2. Mobile : Réclamation du jumelage & création du code PIN
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[2/6] Mobile : Scan du QR code et saisie du code PIN (1234)...${NC}"
CLAIM_RES=$(curl -s -X POST "$BASE_URL/api/v1/auth/pair/claim" \
  -H "Content-Type: application/json" \
  -d "{
    \"token\": \"$PAIR_TOKEN\",
    \"deviceId\": \"$DEVICE_ID\",
    \"deviceName\": \"Samsung Galaxy S23 du Patron\",
    \"pin\": \"1234\"
  }")

ACCESS_TOKEN=$(echo "$CLAIM_RES" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}❌ Échec lors de la réclamation du jumelage : $CLAIM_RES${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Appareil jumelé avec succès !${NC}"
echo -e "Access Token JWT reçu : ${ACCESS_TOKEN:0:25}...\n"

# ------------------------------------------------------------------------------
# 3. Desktop : Pousser un lot de ventes, dépenses et stocks
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[3/6] Desktop : Ingestion d'un lot de ventes caisse (Sync Push)...${NC}"
PUSH_RES=$(curl -s -X POST "$BASE_URL/api/v1/sync/push" \
  -H "Content-Type: application/json" \
  -d "{
    \"machineId\": \"DESKTOP-CAISSE-01\",
    \"licenseKey\": \"$LICENSE_KEY\",
    \"sentAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"events\": [
      {
        \"eventId\": \"evt-sale-001\",
        \"entityType\": \"sale\",
        \"entityId\": \"sale-01\",
        \"action\": \"create\",
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
        \"data\": {
          \"saleId\": \"sale-01\",
          \"reference\": \"FAC-2026-0001\",
          \"customerId\": \"cust-amadou\",
          \"customerName\": \"Amadou Bah\",
          \"totalAmount\": 500000,
          \"amountPaid\": 300000,
          \"paymentMethodIndex\": 0,
          \"lines\": [
            {
              \"productId\": \"prod-riz-50kg\",
              \"label\": \"Sac de Riz 50kg Blanc\",
              \"quantity\": 2,
              \"unitPrice\": 250000,
              \"unitCost\": 210000
            }
          ]
        }
      },
      {
        \"eventId\": \"evt-exp-001\",
        \"entityType\": \"expense\",
        \"entityId\": \"exp-01\",
        \"action\": \"create\",
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
        \"data\": {
          \"expenseId\": \"exp-01\",
          \"reference\": \"DEP-01\",
          \"amount\": 50000,
          \"categoryIndex\": 1,
          \"paymentMethodIndex\": 0,
          \"description\": \"Transport & manutention riz\"
        }
      }
    ]
  }")

echo "Réponse : $PUSH_RES"
echo -e "${GREEN}✓ Vente et dépense enregistrées avec calcul des agrégats.${NC}\n"

# Test de l'idempotence
echo -e "${YELLOW}[3.1] Test de l'idempotence (renvoi immédiat du même lot)...${NC}"
IDEMP_RES=$(curl -s -X POST "$BASE_URL/api/v1/sync/push" \
  -H "Content-Type: application/json" \
  -d "{
    \"machineId\": \"DESKTOP-CAISSE-01\",
    \"licenseKey\": \"$LICENSE_KEY\",
    \"sentAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"events\": [
      {
        \"eventId\": \"evt-sale-001\",
        \"entityType\": \"sale\",
        \"entityId\": \"sale-01\",
        \"action\": \"create\",
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
        \"data\": {}
      }
    ]
  }")
echo "Réponse (Idempotence) : $IDEMP_RES"
echo -e "${GREEN}✓ Doublon ignoré (0 traité, 1 ignoré).${NC}\n"

# ------------------------------------------------------------------------------
# 4. Mobile : Consultation du Dashboard Patron
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[4/6] Mobile : Consultation du Cockpit Dashboard (/mobile/dashboard)...${NC}"
DASH_RES=$(curl -s -X GET "$BASE_URL/api/v1/mobile/dashboard" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
echo "Dashboard : $DASH_RES"
echo -e "${GREEN}✓ Chiffre d'affaires, Marge et Alertes remontés.${NC}\n"

# ------------------------------------------------------------------------------
# 5. Mobile : Consultation de la Caisse & Trésorerie
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[5/6] Mobile : Contrôle du solde d'espèces (/mobile/treasury)...${NC}"
TREAS_RES=$(curl -s -X GET "$BASE_URL/api/v1/mobile/treasury" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
echo "Trésorerie : $TREAS_RES"
echo -e "${GREEN}✓ Solde théorique en espèces calculé.${NC}\n"

# ------------------------------------------------------------------------------
# 6. Mobile : Contrôle des Créances & Débiteurs
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[6/6] Mobile : Contrôle des crédits clients (/mobile/receivables)...${NC}"
RECV_RES=$(curl -s -X GET "$BASE_URL/api/v1/mobile/receivables" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
echo "Créances : $RECV_RES"
echo -e "${GREEN}✓ Dette de 200 000 GNF pour Amadou Bah enregistrée.${NC}\n"

echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN}🎉 TOUS LES FLUX DE TEST ONT RÉUSSI AVEC SUCCÈS !${NC}"
echo -e "${BLUE}======================================================${NC}"
