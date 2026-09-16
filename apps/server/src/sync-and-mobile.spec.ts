import { describe, it, expect, beforeEach } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { DatabaseModule } from './database/database.module.js';
import { AuthModule } from './auth/auth.module.js';
import { SyncModule } from './sync/sync.module.js';
import { MobileModule } from './mobile/mobile.module.js';
import { AuthService } from './auth/auth.service.js';
import { SyncService } from './sync/sync.service.js';
import { MobileService } from './mobile/mobile.service.js';
import crypto from 'crypto';
import { DatabaseService } from './database/database.service.js';
import { CaisseAuthGuard } from './sync/caisse-auth.guard.js';

describe('NMaShop Mobile Ecosystem — Backend Core Integration', () => {
  let authService: AuthService;
  let syncService: SyncService;
  let mobileService: MobileService;
  let db: DatabaseService;

  beforeEach(async () => {
    process.env.DATABASE_DRIVER = 'memory';
    const module: TestingModule = await Test.createTestingModule({
      imports: [DatabaseModule, AuthModule, SyncModule, MobileModule],
    }).compile();

    authService = module.get<AuthService>(AuthService);
    syncService = module.get<SyncService>(SyncService);
    mobileService = module.get<MobileService>(MobileService);
    db = module.get<DatabaseService>(DatabaseService);

    // Initialiser le module base de données (en mémoire ou PostgreSQL)
    await db.onModuleInit();
    await db.cleanAllForTesting();

    // Provisionner les boutiques de test (puisque l'auto-provisionnement a été supprimé)
    await db.upsertShop('TEST-LICENSE-KEY', 'Boutique Diallo & Frères', 'GNF');
    await db.upsertShop('TEST-CANCEL-SHOP', 'Boutique Cancel', 'GNF');
    await db.upsertShop('LICENSE-SHOP-A', 'Shop A', 'GNF');
    await db.upsertShop('LICENSE-SHOP-B', 'Shop B', 'GNF');
    await db.upsertShop('TEST-OUTOFORDER-SHOP', 'Boutique OOO', 'GNF');
  });

  describe('1. Flux de Jumelage & Authentification', () => {
    it('initialise un jeton de jumelage et permet au mobile de le réclamer avec un code PIN', async () => {
      const initRes = await authService.initPairing({
        token: '11111111-1111-1111-1111-111111111111',
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-LICENSE-KEY',
        shopName: 'Boutique Test Diallo',
        currency: 'GNF',
      });

      expect(initRes.success).toBe(true);
      expect(initRes.token).toBe('11111111-1111-1111-1111-111111111111');

      // Réclamation par le mobile du commerçant
      const claimRes = await authService.claimPairing({
        token: '11111111-1111-1111-1111-111111111111',
        deviceId: '33333333-3333-3333-3333-333333333333',
        deviceName: 'Samsung Galaxy A54 du Patron',
        pin: '1234',
      });

      expect(claimRes.success).toBe(true);
      expect(claimRes.accessToken).toBeDefined();
      expect(claimRes.refreshToken).toBeDefined();
      expect(claimRes.shop.name).toBe('Boutique Test Diallo');

      // Tenter de réutiliser le même jeton doit échouer
      await expect(
        authService.claimPairing({
          token: '11111111-1111-1111-1111-111111111111',
          deviceId: '44444444-4444-4444-4444-444444444444',
          deviceName: 'Autre téléphone',
          pin: '9999',
        }),
      ).rejects.toThrow('déjà été utilisé');
    });

    it('authentifie le patron par code PIN sur un appareil déjà jumelé', async () => {
      // Jumelage
      await authService.initPairing({
        token: '55555555-5555-5555-5555-555555555555',
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-LICENSE-KEY',
        shopName: 'Boutique Diallo',
      });
      await authService.claimPairing({
        token: '55555555-5555-5555-5555-555555555555',
        deviceId: '66666666-6666-6666-6666-666666666666',
        deviceName: 'iPhone 13 Patron',
        pin: '5678',
      });

      // Connexion avec PIN correct
      const loginRes = await authService.login({
        deviceId: '66666666-6666-6666-6666-666666666666',
        pin: '5678',
      });
      expect(loginRes.success).toBe(true);
      expect(loginRes.accessToken).toBeDefined();

      // Connexion avec mauvais PIN
      await expect(
        authService.login({
          deviceId: '66666666-6666-6666-6666-666666666666',
          pin: '0000',
        }),
      ).rejects.toThrow('Code PIN incorrect');
    });
  });

  describe('2. Ingestion de Synchronisation & Idempotence', () => {
    it('ingère un lot de ventes, dépenses et stocks, et ignore les doublons idempotents', async () => {
      const batch = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-LICENSE-KEY',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '77777777-7777-7777-7777-777777777777',
            entityType: 'sale',
            entityId: '88888888-8888-8888-8888-888888888888',
            action: 'create',
            timestamp: new Date().toISOString(),
            data: {
              saleId: '88888888-8888-8888-8888-888888888888',
              reference: 'FAC-2026-0001',
              customerId: '99999999-9999-9999-9999-999999999999',
              customerName: 'Amadou Bah',
              totalAmount: 500000,
              amountPaid: 300000, // 200 000 GNF à crédit
              paymentMethodIndex: 0, // Espèces
              lines: [
                {
                  productId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                  label: 'Sac de Riz 50kg',
                  quantity: 2,
                  unitPrice: 250000,
                  unitCost: 210000,
                  lineTotal: 500000,
                },
              ],
            },
          },
          {
            eventId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            entityType: 'expense',
            entityId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
            action: 'create',
            timestamp: new Date().toISOString(),
            data: {
              expenseId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
              reference: 'DEP-001',
              amount: 50000,
              categoryIndex: 1,
              paymentMethodIndex: 0,
              description: 'Carburant pour livraison',
            },
          },
        ],
      };

      // 1er envoi : 2 événements traités
      const push1 = await syncService.processBatch(batch);
      expect(push1.success).toBe(true);
      expect(push1.processedCount).toBe(2);
      expect(push1.skippedCount).toBe(0);

      // 2ème envoi du même lot : 0 traité, 2 ignorés grâce à l'idempotence
      const push2 = await syncService.processBatch(batch);
      expect(push2.success).toBe(true);
      expect(push2.processedCount).toBe(0);
      expect(push2.skippedCount).toBe(2);
    });
  });

  describe('3. Consultation Mobile ("Le téléphone du patron")', () => {
    it('fournit des agrégats exacts pour le dashboard, la caisse, le stock et les créances', async () => {
      // Ingestion préalable de données
      const batch = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-LICENSE-KEY',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '77777777-7777-7777-7777-777777777777',
            entityType: 'sale',
            entityId: '88888888-8888-8888-8888-888888888888',
            action: 'create',
            timestamp: new Date().toISOString(),
            data: {
              saleId: '88888888-8888-8888-8888-888888888888',
              reference: 'FAC-2026-0001',
              customerId: '99999999-9999-9999-9999-999999999999',
              customerName: 'Amadou Bah',
              totalAmount: 500000,
              amountPaid: 300000, // 200 000 GNF à crédit
              paymentMethodIndex: 0, // Espèces
              lines: [
                {
                  productId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                  label: 'Sac de Riz 50kg',
                  quantity: 2,
                  unitPrice: 250000,
                  unitCost: 210000,
                  lineTotal: 500000,
                },
              ],
            },
          },
          {
            eventId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            entityType: 'expense',
            entityId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
            action: 'create',
            timestamp: new Date().toISOString(),
            data: {
              expenseId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
              reference: 'DEP-001',
              amount: 50000,
              categoryIndex: 1,
              paymentMethodIndex: 0,
              description: 'Carburant pour livraison',
            },
          },
        ],
      };
      await syncService.processBatch(batch);

      const tenant = (await db.findShopByLicense('TEST-LICENSE-KEY'))!;

      // Dashboard
      const dashboard = await mobileService.getDashboard(tenant.id);
      expect(dashboard.shop.name).toBeDefined();
      expect(dashboard.today.totalSales).toBe(500000);
      expect(dashboard.today.totalProfit).toBe(80000); // 2 * (250000 - 210000)
      expect(dashboard.today.cashCollected).toBe(300000);
      expect(dashboard.today.creditIssued).toBe(200000);
      expect(dashboard.receivables.totalAmount).toBe(200000);

      // Trésorerie
      const treasury = await mobileService.getTreasury(tenant.id);
      // Espèces encaissées (300 000) - dépenses espèces (50 000) = 250 000 GNF
      expect(treasury.theoreticalCashInHand).toBe(250000);
      expect(treasury.expensesToday).toBe(50000);

      // Stock
      const stock = await mobileService.getStock(tenant.id);
      expect(stock.items.length).toBeGreaterThan(0);
      const riz = stock.items.find((i) => i.productId === 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(riz).toBeDefined();
      expect(riz!.quantity).toBe(-2); // Déduit lors de la vente
      expect(riz!.status).toBe('out'); // Rupture totale

      // Créances clients
      const receivables = await mobileService.getReceivables(tenant.id);
      expect(receivables.totalReceivables).toBe(200000);
      expect(receivables.debtors[0].customerName).toBe('Amadou Bah');

      // Alertes & Acquittement
      const alerts = await mobileService.getAlerts(tenant.id);
      expect(alerts.alerts.length).toBeGreaterThan(0);
      const firstAlert = alerts.alerts[0];
      expect(firstAlert.isRead).toBe(false);

      const ackRes = await mobileService.ackAlert(tenant.id, firstAlert.id);
      expect(ackRes.success).toBe(true);

      const alertsAfter = await mobileService.getAlerts(tenant.id);
      const acked = alertsAfter.alerts.find((a) => a.id === firstAlert.id);
      expect(acked?.isRead).toBe(true);
    });

    it('gère l\'annulation de vente (inversion snapshot, restauration stock, annulation dette)', async () => {
      // 1. Création vente initiale
      const saleBatch = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-CANCEL-SHOP',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '12345678-1234-1234-1234-123456789015',
            entityType: 'sale',
            entityId: '12345678-1234-1234-1234-123456789016',
            action: 'create',
            timestamp: new Date().toISOString(),
            data: {
              saleId: '12345678-1234-1234-1234-123456789016',
              reference: 'FAC-2026-999',
              customerId: '12345678-1234-1234-1234-123456789017',
              customerName: 'Moussa Camara',
              totalAmount: 1000000,
              amountPaid: 600000,
              paymentMethodIndex: 0,
              lines: [
                {
                  productId: '12345678-1234-1234-1234-123456789018',
                  label: 'Bidon Huile 20L',
                  quantity: 3,
                  unitPrice: 300000,
                  unitCost: 250000,
                  lineTotal: 900000,
                },
              ],
            },
          },
        ],
      };
      await syncService.processBatch(saleBatch);
      const tenant = (await db.findShopByLicense('TEST-CANCEL-SHOP'))!;

      // Vérifier état initial
      let dash = await mobileService.getDashboard(tenant.id);
      expect(dash.today.totalSales).toBe(1000000);
      expect(dash.today.cashCollected).toBe(600000);
      expect(dash.today.creditIssued).toBe(400000);
      let stock = await mobileService.getStock(tenant.id);
      let huile = stock.items.find((i) => i.productId === '12345678-1234-1234-1234-123456789018');
      expect(huile?.quantity).toBe(-3);

      // 2. Annulation de la vente
      const cancelBatch = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-CANCEL-SHOP',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '12345678-1234-1234-1234-123456789019',
            entityType: 'sale',
            entityId: '12345678-1234-1234-1234-123456789016',
            action: 'cancel',
            timestamp: new Date().toISOString(),
            data: {
              saleId: '12345678-1234-1234-1234-123456789016',
            },
          },
        ],
      };
      const cancelRes = await syncService.processBatch(cancelBatch);
      expect(cancelRes.processedCount).toBe(1);

      // 3. Vérifier que les agrégats sont inversés à 0
      dash = await mobileService.getDashboard(tenant.id);
      expect(dash.today.totalSales).toBe(0);
      expect(dash.today.cashCollected).toBe(0);
      expect(dash.today.creditIssued).toBe(0);
      expect(dash.today.salesCount).toBe(0);

      // 4. Vérifier que la dette client est annulée
      const rec = await mobileService.getReceivables(tenant.id);
      expect(rec.totalReceivables).toBe(0);

      // 5. Vérifier que le stock a été réintégré (+3 -> 0)
      stock = await mobileService.getStock(tenant.id);
      huile = stock.items.find((i) => i.productId === '12345678-1234-1234-1234-123456789018');
      expect(huile?.quantity).toBe(0);

      // 6. Vérifier alerte d'annulation
      const alerts = await mobileService.getAlerts(tenant.id);
      const cancelAlert = alerts.alerts.find((a) => a.type === 'sale_cancelled');
      expect(cancelAlert).toBeDefined();

      // 7. Vérifier idempotence de la double annulation
      const duplicateCancelBatch = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-CANCEL-SHOP',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '12345678-1234-1234-1234-123456789019-retry',
            entityType: 'sale',
            entityId: '12345678-1234-1234-1234-123456789016',
            action: 'cancel',
            timestamp: new Date().toISOString(),
            data: {
              saleId: '12345678-1234-1234-1234-123456789016',
            },
          },
        ],
      };
      await syncService.processBatch(duplicateCancelBatch);
      dash = await mobileService.getDashboard(tenant.id);
      expect(dash.today.totalSales).toBe(0); // Reste 0, n'est pas devenu négatif !
    });

    it('garantit l\'isolation stricte des données entre locataires (multi-tenancy)', async () => {
      // Tenant A
      await syncService.processBatch({
        machineId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        licenseKey: 'LICENSE-SHOP-A',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
            entityType: 'sale',
            entityId: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
            action: 'create',
            timestamp: new Date().toISOString(),
            data: {
              saleId: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
              totalAmount: 750000,
              amountPaid: 750000,
              paymentMethodIndex: 0,
            },
          },
        ],
      });

      // Tenant B
      await syncService.processBatch({
        machineId: '12345678-1234-1234-1234-123456789012',
        licenseKey: 'LICENSE-SHOP-B',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '12345678-1234-1234-1234-123456789013',
            entityType: 'sale',
            entityId: '12345678-1234-1234-1234-123456789014',
            action: 'create',
            timestamp: new Date().toISOString(),
            data: {
              saleId: '12345678-1234-1234-1234-123456789014',
              totalAmount: 120000,
              amountPaid: 120000,
              paymentMethodIndex: 0,
            },
          },
        ],
      });

      const tenantA = (await db.findShopByLicense('LICENSE-SHOP-A'))!;
      const tenantB = (await db.findShopByLicense('LICENSE-SHOP-B'))!;

      const dashA = await mobileService.getDashboard(tenantA.id);
      const dashB = await mobileService.getDashboard(tenantB.id);

      expect(dashA.today.totalSales).toBe(750000);
      expect(dashB.today.totalSales).toBe(120000);

      // Vérifier que A ne voit pas les ventes de B
      const salesA = await mobileService.getSales(tenantA.id);
      const salesB = await mobileService.getSales(tenantB.id);
      expect(salesA.recentSales.some((s) => s.saleId === '12345678-1234-1234-1234-123456789014')).toBe(false);
      expect(salesB.recentSales.some((s) => s.saleId === 'ffffffff-ffff-ffff-ffff-ffffffffffff')).toBe(false);
    });
  });

  describe('4. Sécurité Avancée Mobile & Anti-Brute-Force', () => {
    it('verrouille l\'appareil après 5 tentatives consécutives de code PIN erroné', async () => {
      await authService.initPairing({
        token: '12345678-1234-1234-1234-123456789021',
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-LOCKOUT-SHOP',
        shopName: 'Boutique Lockout',
      });
      await authService.claimPairing({
        token: '12345678-1234-1234-1234-123456789021',
        deviceId: '12345678-1234-1234-1234-123456789022',
        deviceName: 'Device Lockout',
        pin: '1234',
      });

      // 4 tentatives erronées
      for (let i = 0; i < 4; i++) {
        await expect(
          authService.login({
            deviceId: '12345678-1234-1234-1234-123456789022',
            pin: '9999',
          }),
        ).rejects.toThrow('Code PIN incorrect');
      }

      // 5ème tentative erronée : déclenche le verrouillage
      await expect(
        authService.login({
          deviceId: '12345678-1234-1234-1234-123456789022',
          pin: '9999',
        }),
      ).rejects.toThrow(/verrouillé/i);

      // 6ème tentative, même avec le bon PIN : rejeté car verrouillé
      await expect(
        authService.login({
          deviceId: '12345678-1234-1234-1234-123456789022',
          pin: '1234',
        }),
      ).rejects.toThrow(/verrouillé/i);
    });

    it('gère la rotation stricte du refresh token et interdit la réutilisation d\'anciens jetons', async () => {
      await authService.initPairing({
        token: '12345678-1234-1234-1234-123456789023',
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-REFRESH-SHOP',
        shopName: 'Boutique Refresh',
      });
      const claimRes = await authService.claimPairing({
        token: '12345678-1234-1234-1234-123456789023',
        deviceId: '12345678-1234-1234-1234-123456789024',
        deviceName: 'Device Refresh',
        pin: '1234',
      });

      const oldRefreshToken = claimRes.refreshToken;
      expect(oldRefreshToken).toBeDefined();

      // 1er rafraîchissement légitime
      const refreshRes = await authService.refreshToken(oldRefreshToken);
      expect(refreshRes.success).toBe(true);
      expect(refreshRes.accessToken).toBeDefined();
      expect(refreshRes.refreshToken).toBeDefined();
      expect(refreshRes.refreshToken).not.toBe(oldRefreshToken);

      // Tentative de réutilisation du jeton précédent : REJETÉ
      await expect(
        authService.refreshToken(oldRefreshToken),
      ).rejects.toThrow('Jeton de rafraîchissement déjà utilisé ou révoqué.');
    });
  });

  describe('5. Robustesse Synchronisation & Hors-Ordre', () => {
    it('gère la réception d\'une annulation AVANT la création (out-of-order) via tombstone', async () => {
      const cancelFirstBatch = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-OUTOFORDER-SHOP',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '12345678-1234-1234-1234-123456789025',
            entityType: 'sale',
            entityId: '12345678-1234-1234-1234-123456789026',
            action: 'cancel',
            sequenceNumber: 2,
            timestamp: new Date().toISOString(),
            data: {
              saleId: '12345678-1234-1234-1234-123456789026',
              reference: 'FAC-OOO-001',
              totalAmount: 400000,
            },
          },
        ],
      };

      // Ingestion de l'annulation d'abord
      const cancelRes = await syncService.processBatch(cancelFirstBatch);
      expect(cancelRes.processedCount).toBe(1);

      const tenant = (await db.findShopByLicense('TEST-OUTOFORDER-SHOP'))!;

      // Les agrégats doivent rester à 0
      let dash = await mobileService.getDashboard(tenant.id);
      expect(dash.today.totalSales).toBe(0);
      expect(dash.today.cashCollected).toBe(0);

      // Ingestion tardive de la création de vente
      const createLateBatch = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-OUTOFORDER-SHOP',
        sentAt: new Date().toISOString(),
        events: [
          {
            eventId: '12345678-1234-1234-1234-123456789027',
            entityType: 'sale',
            entityId: '12345678-1234-1234-1234-123456789026',
            action: 'create',
            sequenceNumber: 1,
            timestamp: new Date().toISOString(),
            data: {
              saleId: '12345678-1234-1234-1234-123456789026',
              reference: 'FAC-OOO-001',
              totalAmount: 400000,
              amountPaid: 400000,
              paymentMethodIndex: 0,
              lines: [{ productId: '12345678-1234-1234-1234-123456789028', quantity: 1, unitPrice: 400000, unitCost: 350000 }],
            },
          },
        ],
      };

      const createRes = await syncService.processBatch(createLateBatch);
      expect(createRes.processedCount).toBe(1);

      // La vente était déjà annulée : les agrégats doivent toujours rester à 0 !
      dash = await mobileService.getDashboard(tenant.id);
      expect(dash.today.totalSales).toBe(0);
      expect(dash.today.cashCollected).toBe(0);

      // Le stock ne doit pas être déduit
      const stock = await mobileService.getStock(tenant.id);
      const item = stock.items.find((i) => i.productId === '12345678-1234-1234-1234-123456789028');
      expect(item).toBeUndefined();
    });
  });

  describe('6. Sécurité HMAC & Anti-Rejeu Caisse', () => {
    it('vérifie la signature HMAC-SHA256 et rejette les requêtes falsifiées ou expirées', async () => {
      const initRes = await authService.initPairing({
        token: '12345678-1234-1234-1234-123456789029',
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-HMAC-SHOP',
        shopName: 'Boutique Sécurisée HMAC',
      });
      expect(initRes.caisseSecret).toBeDefined();
      const secret = initRes.caisseSecret!;

      const guard = new CaisseAuthGuard(db);

      const validPayload = {
        machineId: '22222222-2222-2222-2222-222222222222',
        licenseKey: 'TEST-HMAC-SHOP',
        sentAt: new Date().toISOString(),
        events: [],
      };
      const nowIso = new Date().toISOString();
      const rawBody = `${nowIso}.${JSON.stringify(validPayload)}`;
      const validSignature = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');

      // 1. Signature valide -> Succès
      const mockContextValid: any = {
        switchToHttp: () => ({
          getRequest: () => ({
            headers: {
              'x-license-key': 'TEST-HMAC-SHOP',
              'x-machine-id': '22222222-2222-2222-2222-222222222222',
              'x-timestamp': nowIso,
              'x-signature': validSignature,
            },
            body: validPayload,
          }),
        }),
      };
      await expect(guard.canActivate(mockContextValid)).resolves.toBe(true);

      // 2. Signature falsifiée -> Rejet 401
      const mockContextInvalid: any = {
        switchToHttp: () => ({
          getRequest: () => ({
            headers: {
              'x-license-key': 'TEST-HMAC-SHOP',
              'x-machine-id': '22222222-2222-2222-2222-222222222222',
              'x-timestamp': nowIso,
              'x-signature': '0000000000000000000000000000000000000000000000000000000000000000',
            },
            body: validPayload,
          }),
        }),
      };
      await expect(guard.canActivate(mockContextInvalid)).rejects.toThrow('invalide');

      // 3. Timestamp expiré (> 5 minutes) -> Rejet 401 anti-rejeu
      const expiredIso = new Date(Date.now() - 10 * 60 * 1000).toISOString();
      const mockContextExpired: any = {
        switchToHttp: () => ({
          getRequest: () => ({
            headers: {
              'x-license-key': 'TEST-HMAC-SHOP',
              'x-machine-id': '22222222-2222-2222-2222-222222222222',
              'x-timestamp': expiredIso,
              'x-signature': validSignature,
            },
            body: validPayload,
          }),
        }),
      };
      await expect(guard.canActivate(mockContextExpired)).rejects.toThrow(/dérive|expiré/i);
    });
  });
});
