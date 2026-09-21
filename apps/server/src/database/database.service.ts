import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { randomUUID } from 'crypto';
import pg from 'pg';

const { Pool } = pg;

export interface QueryResult<T = any> {
  rows: T[];
  rowCount: number;
}

export interface ShopRecord {
  id: string;
  licenseKey: string;
  businessName: string;
  currency: string;
  phone?: string;
  caisseSecret?: string;
  openingFund?: number;
  isActive: boolean;
  createdAt: Date;
}

export interface DeviceRecord {
  id: string;
  tenantId: string;
  deviceName: string;
  deviceId: string;
  pinHash: string;
  refreshTokenHash?: string;
  failedPinAttempts?: number;
  lockoutUntil?: Date | null;
  lastSeenAt?: Date;
  isRevoked: boolean;
  createdAt: Date;
}

export interface DailySnapshotRecord {
  id?: string;
  tenantId: string;
  snapshotDate: string; // YYYY-MM-DD
  totalSales: number;
  totalProfit: number;
  salesCount: number;
  cashCollected: number;
  momoCollected: number;
  creditIssued: number;
  lastSyncAt: Date;
}

export interface StockItemRecord {
  id?: string;
  tenantId: string;
  productId: string;
  name: string;
  stockQuantity: number;
  lowStockThreshold: number;
  unitPrice: number;
  unitCost: number;
  updatedAt: Date;
}

export interface CustomerDebtRecord {
  id?: string;
  tenantId: string;
  customerId: string;
  customerName: string;
  phone?: string;
  debtAmount: number;
  lastSaleDate: Date;
}

export interface AlertRecord {
  id: string;
  tenantId: string;
  type: string;
  severity: 'info' | 'warning' | 'critical';
  title: string;
  message: string;
  isRead: boolean;
  createdAt: Date;
}

export interface SaleRecord {
  id: string;
  tenantId: string;
  saleId: string;
  reference: string;
  customerName?: string;
  customerId?: string;
  totalAmount: number;
  amountPaid: number;
  profit: number;
  paymentMethodIndex: number;
  mobileMoneyProvider?: string;
  isCancelled?: boolean;
  isPending?: boolean;
  lines?: any[];
  createdAt: Date;
}

export interface ExpenseRecord {
  id: string;
  tenantId: string;
  expenseId: string;
  reference: string;
  categoryIndex: number;
  amount: number;
  paymentMethodIndex: number;
  description?: string;
  createdAt: Date;
}

export interface CashMovementRecord {
  id: string;
  tenantId: string;
  movementId: string;
  reference: string;
  description: string;
  amount: number;
  typeIndex: number; // 0: in, 1: out
  paymentMethodIndex: number;
  createdAt: Date;
}

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pool: pg.Pool | null = null;
  private isMemoryFallback = false;

  public memoryStore = {
    shops: new Map<string, ShopRecord>(),
    devices: new Map<string, DeviceRecord>(),
    pairingTokens: new Map<string, { tenantId: string; shopName: string; currency: string; expiresAt: Date; consumed: boolean }>(),
    syncEvents: new Set<string>(),
    dailySnapshots: new Map<string, DailySnapshotRecord>(),
    stock: new Map<string, StockItemRecord>(),
    debts: new Map<string, CustomerDebtRecord>(),
    alerts: new Map<string, AlertRecord>(),
    sales: new Map<string, SaleRecord>(),
    expenses: new Map<string, ExpenseRecord>(),
    cashMovements: new Map<string, CashMovementRecord>(),
  };

  constructor() {
    this.isMemoryFallback = false;
  }

  async onModuleInit() {
    const connectionString = process.env.DATABASE_URL || process.env.NEON_DATABASE_URL || process.env.NEON_CONNECTION_STRING;

    if (process.env.DATABASE_DRIVER === 'memory' || process.env.NODE_ENV === 'test' || process.env.VITEST === 'true') {
      this.isMemoryFallback = true;
      this.logger.warn('Mode mémoire actif pour les tests ou développement local.');
      return;
    }

    if (!connectionString) {
      throw new Error('DATABASE_URL est obligatoire en production (et sans DATABASE_DRIVER=memory). Démarrage du serveur refusé.');
    }

    try {
      this.pool = new Pool({
        connectionString,
        ssl: connectionString.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
        max: 10,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 5000,
      });

      // Test connection
      const client = await this.pool.connect();
      client.release();
      this.logger.log('Connecté à PostgreSQL avec succès.');
      this.isMemoryFallback = false;
      await this.initPostgresSchema();
    } catch (err) {
      if (process.env.NODE_ENV === 'production') {
        throw new Error(`Échec critique de connexion à PostgreSQL: ${err}. Démarrage refusé. FAIL FAST actif.`);
      } else {
        this.isMemoryFallback = true;
        this.logger.warn(`Impossible de joindre PostgreSQL (${err}). Basculement automatique en mode mémoire pour le développement local.`);
      }
    }
  }

  async onModuleDestroy() {
    if (this.pool) {
      await this.pool.end();
    }
  }

  async cleanAllForTesting() {
    if (this.isMemoryFallback) {
      this.memoryStore = {
        shops: new Map(),
        devices: new Map(),
        pairingTokens: new Map(),
        syncEvents: new Set(),
        dailySnapshots: new Map(),
        stock: new Map(),
        debts: new Map(),
        sales: new Map(),
        expenses: new Map(),
        cashMovements: new Map(),
        alerts: new Map(),
      };
      return;
    }
    if (this.pool) {
      await this.query('TRUNCATE shops, devices, pairing_tokens, sync_events, daily_snapshots, stock_items, customer_debts, alerts, sales_records, expenses, cash_movements CASCADE');
    }
  }

  private async initPostgresSchema() {
    if (!this.pool) return;
    const client = await this.pool.connect();
    try {
      await client.query(`
        CREATE TABLE IF NOT EXISTS shops (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          license_key VARCHAR(128) UNIQUE NOT NULL,
          business_name VARCHAR(255) NOT NULL,
          currency VARCHAR(10) DEFAULT 'GNF',
          phone VARCHAR(50),
          is_active BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          caisse_secret VARCHAR(128),
          opening_fund BIGINT DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS devices (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          device_name VARCHAR(100) NOT NULL,
          device_id VARCHAR(128) NOT NULL,
          pin_hash VARCHAR(255) NOT NULL,
          refresh_token_hash VARCHAR(255),
          last_seen_at TIMESTAMPTZ,
          is_revoked BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          failed_pin_attempts INT DEFAULT 0,
          lockout_until TIMESTAMPTZ,
          CONSTRAINT uq_tenant_device UNIQUE(tenant_id, device_id)
        );

        CREATE TABLE IF NOT EXISTS pairing_tokens (
          token VARCHAR(128) PRIMARY KEY,
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          shop_name VARCHAR(255) NOT NULL,
          currency VARCHAR(10) DEFAULT 'GNF',
          expires_at TIMESTAMPTZ NOT NULL,
          consumed BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS sync_events (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          event_id UUID NOT NULL,
          event_type VARCHAR(50) NOT NULL,
          payload JSONB NOT NULL,
          received_at TIMESTAMPTZ DEFAULT NOW(),
          sequence_number BIGINT DEFAULT 0,
          machine_id UUID,
          CONSTRAINT uq_tenant_event UNIQUE(tenant_id, event_id)
        );

        CREATE TABLE IF NOT EXISTS daily_snapshots (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          snapshot_date DATE NOT NULL,
          total_sales BIGINT DEFAULT 0,
          total_profit BIGINT DEFAULT 0,
          sales_count INT DEFAULT 0,
          cash_collected BIGINT DEFAULT 0,
          momo_collected BIGINT DEFAULT 0,
          credit_issued BIGINT DEFAULT 0,
          last_sync_at TIMESTAMPTZ DEFAULT NOW(),
          CONSTRAINT uq_tenant_daily_snapshot UNIQUE(tenant_id, snapshot_date)
        );

        CREATE TABLE IF NOT EXISTS stock_items (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          product_id UUID NOT NULL,
          name VARCHAR(255) NOT NULL,
          stock_quantity INT DEFAULT 0,
          low_stock_threshold INT DEFAULT 0,
          unit_price INT DEFAULT 0,
          unit_cost INT DEFAULT 0,
          updated_at TIMESTAMPTZ DEFAULT NOW(),
          CONSTRAINT uq_tenant_product UNIQUE(tenant_id, product_id)
        );

        CREATE TABLE IF NOT EXISTS customer_debts (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          customer_id UUID NOT NULL,
          customer_name VARCHAR(255) NOT NULL,
          phone VARCHAR(50),
          debt_amount BIGINT DEFAULT 0,
          last_sale_date TIMESTAMPTZ DEFAULT NOW(),
          CONSTRAINT uq_tenant_customer UNIQUE(tenant_id, customer_id)
        );

        CREATE TABLE IF NOT EXISTS alerts (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          type VARCHAR(50) NOT NULL,
          severity VARCHAR(20) NOT NULL,
          title VARCHAR(255) NOT NULL,
          message TEXT NOT NULL,
          is_read BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS sales_records (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          sale_id UUID NOT NULL,
          reference VARCHAR(100) NOT NULL,
          customer_name VARCHAR(255),
          customer_id UUID,
          total_amount BIGINT DEFAULT 0,
          amount_paid BIGINT DEFAULT 0,
          profit BIGINT DEFAULT 0,
          payment_method_index INT DEFAULT 0,
          mobile_money_provider VARCHAR(50),
          is_cancelled BOOLEAN DEFAULT FALSE,
          is_pending BOOLEAN DEFAULT FALSE,
          lines JSONB DEFAULT '[]',
          created_at TIMESTAMPTZ DEFAULT NOW(),
          CONSTRAINT uq_tenant_sale UNIQUE(tenant_id, sale_id)
        );

        CREATE TABLE IF NOT EXISTS expenses (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          expense_id UUID NOT NULL,
          reference VARCHAR(100) NOT NULL,
          category_index INT DEFAULT 0,
          amount BIGINT DEFAULT 0,
          payment_method_index INT DEFAULT 0,
          description TEXT,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          CONSTRAINT uq_tenant_expense UNIQUE(tenant_id, expense_id)
        );

        CREATE TABLE IF NOT EXISTS cash_movements (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          tenant_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
          movement_id UUID NOT NULL,
          reference VARCHAR(100) NOT NULL,
          description TEXT,
          amount BIGINT DEFAULT 0,
          type_index INT DEFAULT 0,
          payment_method_index INT DEFAULT 0,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          CONSTRAINT uq_tenant_movement UNIQUE(tenant_id, movement_id)
        );
      `);
      this.logger.log('Schéma PostgreSQL initialisé et vérifié.');
    } finally {
      client.release();
    }
  }

  async query<T = any>(sql: string, params: any[] = []): Promise<QueryResult<T>> {
    if (this.pool && !this.isMemoryFallback) {
      const res = await this.pool.query(sql, params);
      return { rows: res.rows, rowCount: res.rowCount ?? 0 };
    }
    return { rows: [], rowCount: 0 };
  }

  async withTransaction<T>(callback: (client: pg.PoolClient | null) => Promise<T>): Promise<T> {
    if (this.isMemoryFallback || !this.pool) {
      return callback(null);
    }
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async queryWithClient<T = any>(client: pg.PoolClient | null, sql: string, params: any[] = []): Promise<QueryResult<T>> {
    if (client) {
      const res = await client.query(sql, params);
      return { rows: res.rows, rowCount: res.rowCount ?? 0 };
    }
    return this.query<T>(sql, params);
  }

  get isFallback(): boolean {
    return this.isMemoryFallback;
  }

  // --- REPOSITORY / HELPER METHODS ---

  async findShopByLicense(licenseKey: string): Promise<ShopRecord | null> {
    if (this.isMemoryFallback) {
      for (const shop of this.memoryStore.shops.values()) {
        if (shop.licenseKey === licenseKey) return shop;
      }
      return null;
    }
    const res = await this.query<ShopRecord>(
      'SELECT id, license_key as "licenseKey", business_name as "businessName", currency, phone, caisse_secret as "caisseSecret", opening_fund as "openingFund", is_active as "isActive", created_at as "createdAt" FROM shops WHERE license_key = $1 LIMIT 1',
      [licenseKey],
    );
    return res.rows[0] ?? null;
  }

  async findShopById(id: string): Promise<ShopRecord | null> {
    if (this.isMemoryFallback) {
      if (!this.memoryStore.shops.has(id)) {
        this.seedDemoStoreForTenant(id);
      }
      return this.memoryStore.shops.get(id) ?? null;
    }
    const res = await this.query<ShopRecord>(
      'SELECT id, license_key as "licenseKey", business_name as "businessName", currency, phone, caisse_secret as "caisseSecret", opening_fund as "openingFund", is_active as "isActive", created_at as "createdAt" FROM shops WHERE id = $1 LIMIT 1',
      [id],
    );
    return res.rows[0] ?? null;
  }

  public seedDemoStoreForTenant(tenantId: string) {
    const todayStr = new Date().toISOString().split('T')[0];
    if (!this.memoryStore.shops.has(tenantId)) {
      const shop: ShopRecord = {
        id: tenantId,
        licenseKey: 'NMA-2026-GUINEE-OFFICIEL',
        businessName: 'Boutique N\'MaShop Guinée',
        currency: 'GNF',
        phone: '+224 622 00 11 22',
        isActive: true,
        createdAt: new Date(),
      };
      this.memoryStore.shops.set(tenantId, shop);
    }

    this.memoryStore.dailySnapshots.set(`${tenantId}:${todayStr}`, {
      tenantId,
      snapshotDate: todayStr,
      totalSales: 6450000,
      totalProfit: 1850000,
      salesCount: 22,
      cashCollected: 4200000,
      momoCollected: 1750000,
      creditIssued: 500000,
      lastSyncAt: new Date(),
    });

    this.memoryStore.stock.set(`${tenantId}:prod-1`, {
      tenantId,
      productId: 'prod-1',
      name: 'Huile Mayonnaise 5L',
      stockQuantity: 0,
      lowStockThreshold: 5,
      unitPrice: 145000,
      unitCost: 110000,
      updatedAt: new Date(),
    });
    this.memoryStore.stock.set(`${tenantId}:prod-2`, {
      tenantId,
      productId: 'prod-2',
      name: 'Sac de Riz Blanc 50kg',
      stockQuantity: 4,
      lowStockThreshold: 10,
      unitPrice: 340000,
      unitCost: 290000,
      updatedAt: new Date(),
    });
    this.memoryStore.stock.set(`${tenantId}:prod-3`, {
      tenantId,
      productId: 'prod-3',
      name: 'Sucre En Poudre 25kg',
      stockQuantity: 5,
      lowStockThreshold: 5,
      unitPrice: 220000,
      unitCost: 185000,
      updatedAt: new Date(),
    });
    this.memoryStore.stock.set(`${tenantId}:prod-4`, {
      tenantId,
      productId: 'prod-4',
      name: 'Lait Concentré Bonnet Rouge',
      stockQuantity: 48,
      lowStockThreshold: 12,
      unitPrice: 8500,
      unitCost: 6500,
      updatedAt: new Date(),
    });

    this.memoryStore.debts.set(`${tenantId}:debtor-1`, {
      tenantId,
      customerId: 'debtor-1',
      customerName: 'Elhadj Ousmane Camara',
      phone: '+224 622 14 55 88',
      debtAmount: 1250000,
      lastSaleDate: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
    });
    this.memoryStore.debts.set(`${tenantId}:debtor-2`, {
      tenantId,
      customerId: 'debtor-2',
      customerName: 'Thierno Souleymane',
      phone: '+224 664 90 21 03',
      debtAmount: 950000,
      lastSaleDate: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
    });

    this.memoryStore.alerts.set(`${tenantId}:alt-1`, {
      id: `${tenantId}:alt-1`,
      tenantId,
      type: 'stock',
      severity: 'critical',
      title: 'Rupture de stock critique',
      message: 'Huile Mayonnaise 5L épuisée en magasin.',
      isRead: false,
      createdAt: new Date(Date.now() - 30 * 60 * 1000),
    });
    this.memoryStore.alerts.set(`${tenantId}:alt-2`, {
      id: `${tenantId}:alt-2`,
      tenantId,
      type: 'caisse',
      severity: 'warning',
      title: 'Solde d\'espèces caisse',
      message: 'Versement de 4 200 000 GNF enregistré en caisse.',
      isRead: false,
      createdAt: new Date(Date.now() - 2 * 3600 * 1000),
    });

    this.memoryStore.sales.set(`${tenantId}:sale-001`, {
      id: 'sale-001',
      tenantId,
      saleId: 'sale-001',
      reference: 'FAC-2026-102',
      customerName: 'Mamadou Diallo',
      totalAmount: 1850000,
      amountPaid: 1850000,
      profit: 450000,
      paymentMethodIndex: 0,
      createdAt: new Date(Date.now() - 15 * 60 * 1000),
    });
    this.memoryStore.sales.set(`${tenantId}:sale-002`, {
      id: 'sale-002',
      tenantId,
      saleId: 'sale-002',
      reference: 'FAC-2026-101',
      customerName: 'Kadiatou Bah',
      totalAmount: 1250000,
      amountPaid: 1250000,
      profit: 320000,
      paymentMethodIndex: 1,
      mobileMoneyProvider: 'Orange Money',
      createdAt: new Date(Date.now() - 75 * 60 * 1000),
    });
  }

  async saveCaisseSecret(shopId: string, caisseSecret: string) {
    if (this.isMemoryFallback) {
      const shop = this.memoryStore.shops.get(shopId);
      if (shop) shop.caisseSecret = caisseSecret;
      return;
    }
    await this.query('UPDATE shops SET caisse_secret = $1 WHERE id = $2', [caisseSecret, shopId]);
  }

  async upsertShop(licenseKey: string, businessName: string, currency = 'GNF'): Promise<ShopRecord> {
    const existing = await this.findShopByLicense(licenseKey);
    if (existing) {
      existing.businessName = businessName;
      existing.currency = currency;
      return existing;
    }

    const newShop: ShopRecord = {
      id: randomUUID(),
      licenseKey,
      businessName,
      currency,
      openingFund: 0,
      isActive: true,
      createdAt: new Date(),
    };

    if (this.isMemoryFallback) {
      this.memoryStore.shops.set(newShop.id, newShop);
      return newShop;
    }

    const res = await this.query<ShopRecord>(
      `INSERT INTO shops (id, license_key, business_name, currency) VALUES ($1, $2, $3, $4)
       ON CONFLICT (license_key) DO UPDATE SET business_name = EXCLUDED.business_name, currency = EXCLUDED.currency
       RETURNING id, license_key as "licenseKey", business_name as "businessName", currency, phone, caisse_secret as "caisseSecret", opening_fund as "openingFund", is_active as "isActive", created_at as "createdAt"`,
      [newShop.id, licenseKey, businessName, currency],
    );
    return res.rows[0];
  }

  async savePairingToken(token: string, tenantId: string, shopName: string, currency = 'GNF', expiresAt?: Date) {
    const expiry = expiresAt ?? new Date(Date.now() + 10 * 60 * 1000);
    if (this.isMemoryFallback) {
      this.memoryStore.pairingTokens.set(token, {
        tenantId,
        shopName,
        currency,
        expiresAt: expiry,
        consumed: false,
      });
      return;
    }
    await this.query(
      `INSERT INTO pairing_tokens (token, tenant_id, shop_name, currency, expires_at, consumed)
       VALUES ($1, $2, $3, $4, $5, FALSE)
       ON CONFLICT (token) DO UPDATE SET expires_at = $5, consumed = FALSE`,
      [token, tenantId, shopName, currency, expiry],
    );
  }

  async getPairingToken(token: string) {
    if (this.isMemoryFallback) {
      return this.memoryStore.pairingTokens.get(token) ?? null;
    }
    const res = await this.query(
      'SELECT token, tenant_id as "tenantId", shop_name as "shopName", currency, expires_at as "expiresAt", consumed FROM pairing_tokens WHERE token = $1',
      [token],
    );
    return res.rows[0] ?? null;
  }

  async consumePairingToken(token: string) {
    if (this.isMemoryFallback) {
      const entry = this.memoryStore.pairingTokens.get(token);
      if (entry) entry.consumed = true;
      return;
    }
    await this.query('UPDATE pairing_tokens SET consumed = TRUE WHERE token = $1', [token]);
  }

  async findDevice(deviceId: string): Promise<DeviceRecord | null> {
    if (this.isMemoryFallback) {
      return this.memoryStore.devices.get(deviceId) ?? null;
    }
    const res = await this.query<DeviceRecord>(
      'SELECT id, tenant_id as "tenantId", device_name as "deviceName", device_id as "deviceId", pin_hash as "pinHash", refresh_token_hash as "refreshTokenHash", failed_pin_attempts as "failedPinAttempts", lockout_until as "lockoutUntil", last_seen_at as "lastSeenAt", is_revoked as "isRevoked", created_at as "createdAt" FROM devices WHERE device_id = $1 AND is_revoked = FALSE LIMIT 1',
      [deviceId],
    );
    return res.rows[0] ?? null;
  }

  async saveDevice(device: { tenantId: string; deviceId: string; deviceName: string; pinHash: string; refreshTokenHash?: string }): Promise<DeviceRecord> {
    const record: DeviceRecord = {
      id: randomUUID(),
      tenantId: device.tenantId,
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      pinHash: device.pinHash,
      refreshTokenHash: device.refreshTokenHash,
      failedPinAttempts: 0,
      lockoutUntil: null,
      lastSeenAt: new Date(),
      isRevoked: false,
      createdAt: new Date(),
    };

    if (this.isMemoryFallback) {
      this.memoryStore.devices.set(device.deviceId, record);
      return record;
    }

    const res = await this.query<DeviceRecord>(
      `INSERT INTO devices (id, tenant_id, device_name, device_id, pin_hash, refresh_token_hash, last_seen_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())
       ON CONFLICT (tenant_id, device_id)
       DO UPDATE SET device_name = $3, pin_hash = $5, refresh_token_hash = $6, last_seen_at = NOW(), is_revoked = FALSE
       RETURNING id, tenant_id as "tenantId", device_name as "deviceName", device_id as "deviceId", pin_hash as "pinHash", refresh_token_hash as "refreshTokenHash", failed_pin_attempts as "failedPinAttempts", lockout_until as "lockoutUntil", last_seen_at as "lastSeenAt", is_revoked as "isRevoked", created_at as "createdAt"`,
      [record.id, device.tenantId, device.deviceName, device.deviceId, device.pinHash, device.refreshTokenHash],
    );
    return res.rows[0];
  }

  async registerMobileShopAndDevice(params: {
    licenseKey: string;
    shopName: string;
    currency: string;
    deviceId: string;
    deviceName: string;
    pinHash: string;
    refreshTokenHash: string;
  }): Promise<{ shop: ShopRecord; device: DeviceRecord }> {
    if (this.isMemoryFallback) {
      if (this.memoryStore.devices.has(params.deviceId)) {
        throw new Error('DEVICE_ALREADY_EXISTS');
      }
      const shopId = randomUUID();
      const shop: ShopRecord = {
        id: shopId,
        licenseKey: params.licenseKey,
        businessName: params.shopName,
        currency: params.currency || 'GNF',
        openingFund: 0,
        isActive: true,
        createdAt: new Date(),
      };
      const deviceRecordId = randomUUID();
      const device: DeviceRecord = {
        id: deviceRecordId,
        tenantId: shopId,
        deviceId: params.deviceId,
        deviceName: params.deviceName,
        pinHash: params.pinHash,
        refreshTokenHash: params.refreshTokenHash,
        failedPinAttempts: 0,
        lockoutUntil: null,
        lastSeenAt: new Date(),
        isRevoked: false,
        createdAt: new Date(),
      };
      this.memoryStore.shops.set(shopId, shop);
      this.memoryStore.devices.set(params.deviceId, device);
      return { shop, device };
    }

    return this.withTransaction(async (client) => {
      const devCheck = await this.queryWithClient(
        client,
        'SELECT id FROM devices WHERE device_id = $1 LIMIT 1',
        [params.deviceId],
      );
      if (devCheck.rowCount > 0) {
        throw new Error('DEVICE_ALREADY_EXISTS');
      }

      const shopId = randomUUID();
      const shopRes = await this.queryWithClient<ShopRecord>(
        client,
        `INSERT INTO shops (id, license_key, business_name, currency, is_active)
         VALUES ($1, $2, $3, $4, TRUE)
         RETURNING id, license_key as "licenseKey", business_name as "businessName", currency, phone, caisse_secret as "caisseSecret", opening_fund as "openingFund", is_active as "isActive", created_at as "createdAt"`,
        [shopId, params.licenseKey, params.shopName, params.currency || 'GNF'],
      );
      const shop = shopRes.rows[0];

      const deviceRecordId = randomUUID();
      const devRes = await this.queryWithClient<DeviceRecord>(
        client,
        `INSERT INTO devices (id, tenant_id, device_name, device_id, pin_hash, refresh_token_hash, last_seen_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         RETURNING id, tenant_id as "tenantId", device_name as "deviceName", device_id as "deviceId", pin_hash as "pinHash", refresh_token_hash as "refreshTokenHash", failed_pin_attempts as "failedPinAttempts", lockout_until as "lockoutUntil", last_seen_at as "lastSeenAt", is_revoked as "isRevoked", created_at as "createdAt"`,
        [deviceRecordId, shop.id, params.deviceName, params.deviceId, params.pinHash, params.refreshTokenHash],
      );
      const device = devRes.rows[0];

      return { shop, device };
    });
  }

  async updateDeviceLastSeen(deviceId: string) {
    if (this.isMemoryFallback) {
      const dev = this.memoryStore.devices.get(deviceId);
      if (dev) dev.lastSeenAt = new Date();
      return;
    }
    await this.query('UPDATE devices SET last_seen_at = NOW() WHERE device_id = $1', [deviceId]);
  }

  async updateDeviceRefreshToken(deviceId: string, refreshTokenHash: string) {
    if (this.isMemoryFallback) {
      const dev = this.memoryStore.devices.get(deviceId);
      if (dev) dev.refreshTokenHash = refreshTokenHash;
      return;
    }
    await this.query('UPDATE devices SET refresh_token_hash = $1 WHERE device_id = $2', [refreshTokenHash, deviceId]);
  }

  async updateDeviceFailedPin(deviceId: string, failedCount: number, lockoutUntil: Date | null) {
    if (this.isMemoryFallback) {
      const dev = this.memoryStore.devices.get(deviceId);
      if (dev) {
        dev.failedPinAttempts = failedCount;
        dev.lockoutUntil = lockoutUntil;
      }
      return;
    }
    await this.query('UPDATE devices SET failed_pin_attempts = $1, lockout_until = $2 WHERE device_id = $3', [failedCount, lockoutUntil, deviceId]);
  }

  async resetDeviceLockout(deviceId: string) {
    if (this.isMemoryFallback) {
      const dev = this.memoryStore.devices.get(deviceId);
      if (dev) {
        dev.failedPinAttempts = 0;
        dev.lockoutUntil = null;
      }
      return;
    }
    await this.query('UPDATE devices SET failed_pin_attempts = 0, lockout_until = NULL WHERE device_id = $1', [deviceId]);
  }

  async hasSyncEvent(tenantId: string, eventId: string, client?: pg.PoolClient | null): Promise<boolean> {
    const key = `${tenantId}:${eventId}`;
    if (this.isMemoryFallback) {
      return this.memoryStore.syncEvents.has(key);
    }
    const res = await this.queryWithClient(client || null, 'SELECT 1 FROM sync_events WHERE tenant_id = $1 AND event_id = $2 LIMIT 1', [tenantId, eventId]);
    return res.rowCount > 0;
  }

  async saveSyncEvent(tenantId: string, eventId: string, eventType: string, sequenceNumber = 0, machineId = '', payload: any = {}, client?: pg.PoolClient | null) {
    const key = `${tenantId}:${eventId}`;
    if (this.isMemoryFallback) {
      this.memoryStore.syncEvents.add(key);
      return;
    }
    await this.queryWithClient(
      client || null,
      `INSERT INTO sync_events (tenant_id, event_id, event_type, sequence_number, machine_id, payload) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT DO NOTHING`,
      [tenantId, eventId, eventType, sequenceNumber, machineId, JSON.stringify(payload)],
    );
  }

  // --- AGGREGATION & DATA APPLICATION METHODS ---

  async updateDailySnapshot(tenantId: string, date: string, delta: {
    totalSales?: number;
    totalProfit?: number;
    salesCount?: number;
    cashCollected?: number;
    momoCollected?: number;
    creditIssued?: number;
  }, client?: pg.PoolClient | null) {
    const key = `${tenantId}:${date}`;
    const now = new Date();

    if (this.isMemoryFallback) {
      const snap = this.memoryStore.dailySnapshots.get(key) || {
        tenantId,
        snapshotDate: date,
        totalSales: 0,
        totalProfit: 0,
        salesCount: 0,
        cashCollected: 0,
        momoCollected: 0,
        creditIssued: 0,
        lastSyncAt: now,
      };

      snap.totalSales += delta.totalSales || 0;
      snap.totalProfit += delta.totalProfit || 0;
      snap.salesCount += delta.salesCount || 0;
      snap.cashCollected += delta.cashCollected || 0;
      snap.momoCollected += delta.momoCollected || 0;
      snap.creditIssued += delta.creditIssued || 0;
      snap.lastSyncAt = now;

      this.memoryStore.dailySnapshots.set(key, snap);
      return snap;
    }

    const res = await this.queryWithClient<DailySnapshotRecord>(
      client || null,
      `INSERT INTO daily_snapshots (tenant_id, snapshot_date, total_sales, total_profit, sales_count, cash_collected, momo_collected, credit_issued, last_sync_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
       ON CONFLICT (tenant_id, snapshot_date)
       DO UPDATE SET
         total_sales = daily_snapshots.total_sales + EXCLUDED.total_sales,
         total_profit = daily_snapshots.total_profit + EXCLUDED.total_profit,
         sales_count = daily_snapshots.sales_count + EXCLUDED.sales_count,
         cash_collected = daily_snapshots.cash_collected + EXCLUDED.cash_collected,
         momo_collected = daily_snapshots.momo_collected + EXCLUDED.momo_collected,
         credit_issued = daily_snapshots.credit_issued + EXCLUDED.credit_issued,
         last_sync_at = NOW()
       RETURNING *`,
      [
        tenantId,
        date,
        delta.totalSales || 0,
        delta.totalProfit || 0,
        delta.salesCount || 0,
        delta.cashCollected || 0,
        delta.momoCollected || 0,
        delta.creditIssued || 0,
      ],
    );
    return res.rows[0];
  }

  async saveSaleRecord(sale: SaleRecord, client?: pg.PoolClient | null) {
    if (this.isMemoryFallback) {
      this.memoryStore.sales.set(`${sale.tenantId}:${sale.saleId}`, sale);
      return;
    }
    await this.queryWithClient(
      client || null,
      `INSERT INTO sales_records (tenant_id, sale_id, reference, customer_name, customer_id, total_amount, amount_paid, profit, payment_method_index, mobile_money_provider, is_cancelled, is_pending, lines, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       ON CONFLICT (tenant_id, sale_id) DO UPDATE SET
         reference = EXCLUDED.reference,
         customer_name = COALESCE(EXCLUDED.customer_name, sales_records.customer_name),
         customer_id = COALESCE(EXCLUDED.customer_id, sales_records.customer_id),
         total_amount = EXCLUDED.total_amount,
         amount_paid = EXCLUDED.amount_paid,
         profit = EXCLUDED.profit,
         payment_method_index = EXCLUDED.payment_method_index,
         mobile_money_provider = EXCLUDED.mobile_money_provider,
         is_cancelled = EXCLUDED.is_cancelled,
         is_pending = EXCLUDED.is_pending,
         lines = EXCLUDED.lines`,
      [
        sale.tenantId,
        sale.saleId,
        sale.reference,
        sale.customerName,
        sale.customerId,
        sale.totalAmount,
        sale.amountPaid,
        sale.profit,
        sale.paymentMethodIndex,
        sale.mobileMoneyProvider,
        sale.isCancelled ?? false,
        sale.isPending ?? false,
        JSON.stringify(sale.lines ?? []),
        sale.createdAt,
      ],
    );
  }

  async getSaleRecord(tenantId: string, saleId: string, client?: pg.PoolClient | null): Promise<SaleRecord | null> {
    if (this.isMemoryFallback) {
      return this.memoryStore.sales.get(`${tenantId}:${saleId}`) || null;
    }
    const res = await this.queryWithClient(
      client || null,
      `SELECT * FROM sales_records WHERE tenant_id = $1 AND sale_id = $2 LIMIT 1`,
      [tenantId, saleId],
    );
    if (!res.rows[0]) return null;
    const row = res.rows[0];
    return {
      id: row.id,
      tenantId: row.tenant_id,
      saleId: row.sale_id,
      reference: row.reference,
      customerName: row.customer_name,
      customerId: row.customer_id,
      totalAmount: Number(row.total_amount),
      amountPaid: Number(row.amount_paid),
      profit: Number(row.profit),
      paymentMethodIndex: Number(row.payment_method_index),
      mobileMoneyProvider: row.mobile_money_provider,
      isCancelled: row.is_cancelled === true,
      isPending: row.is_pending === true,
      lines: typeof row.lines === 'string' ? JSON.parse(row.lines) : (row.lines || []),
      createdAt: row.created_at,
    };
  }

  async markSaleCancelled(tenantId: string, saleId: string, client?: pg.PoolClient | null) {
    if (this.isMemoryFallback) {
      const sale = this.memoryStore.sales.get(`${tenantId}:${saleId}`);
      if (sale) {
        sale.isCancelled = true;
      }
      return;
    }
    await this.queryWithClient(
      client || null,
      `UPDATE sales_records SET is_cancelled = true WHERE tenant_id = $1 AND sale_id = $2`,
      [tenantId, saleId],
    );
  }

  async saveExpenseRecord(expense: ExpenseRecord, client?: pg.PoolClient | null) {
    if (this.isMemoryFallback) {
      this.memoryStore.expenses.set(`${expense.tenantId}:${expense.expenseId}`, expense);
      return;
    }
    await this.queryWithClient(
      client || null,
      `INSERT INTO expenses (tenant_id, expense_id, reference, category_index, amount, payment_method_index, description, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (tenant_id, expense_id) DO NOTHING`,
      [
        expense.tenantId,
        expense.expenseId,
        expense.reference,
        expense.categoryIndex,
        expense.amount,
        expense.paymentMethodIndex,
        expense.description,
        expense.createdAt,
      ],
    );
  }

  async saveCashMovementRecord(movement: CashMovementRecord, client?: pg.PoolClient | null) {
    if (this.isMemoryFallback) {
      this.memoryStore.cashMovements.set(`${movement.tenantId}:${movement.movementId}`, movement);
      return;
    }
    await this.queryWithClient(
      client || null,
      `INSERT INTO cash_movements (tenant_id, movement_id, reference, description, amount, type_index, payment_method_index, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (tenant_id, movement_id) DO NOTHING`,
      [
        movement.tenantId,
        movement.movementId,
        movement.reference,
        movement.description,
        movement.amount,
        movement.typeIndex,
        movement.paymentMethodIndex,
        movement.createdAt,
      ],
    );
  }

  async upsertStockItem(tenantId: string, item: { productId: string; name: string; stockDelta?: number; lowStockThreshold?: number; unitPrice?: number; unitCost?: number }, client?: pg.PoolClient | null) {
    const key = `${tenantId}:${item.productId}`;
    const now = new Date();

    if (this.isMemoryFallback) {
      const existing = this.memoryStore.stock.get(key) || {
        tenantId,
        productId: item.productId,
        name: item.name,
        stockQuantity: 0,
        lowStockThreshold: item.lowStockThreshold ?? 5,
        unitPrice: item.unitPrice ?? 0,
        unitCost: item.unitCost ?? 0,
        updatedAt: now,
      };

      if (item.name) existing.name = item.name;
      if (item.stockDelta !== undefined) existing.stockQuantity += item.stockDelta;
      if (item.lowStockThreshold !== undefined) existing.lowStockThreshold = item.lowStockThreshold;
      if (item.unitPrice !== undefined) existing.unitPrice = item.unitPrice;
      if (item.unitCost !== undefined) existing.unitCost = item.unitCost;
      existing.updatedAt = now;

      this.memoryStore.stock.set(key, existing);
      return existing;
    }

    const res = await this.queryWithClient<any>(
      client || null,
      `INSERT INTO stock_items (tenant_id, product_id, name, stock_quantity, low_stock_threshold, unit_price, unit_cost, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       ON CONFLICT (tenant_id, product_id)
       DO UPDATE SET
         name = COALESCE(NULLIF($3, ''), stock_items.name),
         stock_quantity = stock_items.stock_quantity + $4,
         low_stock_threshold = COALESCE(NULLIF($5, 0), stock_items.low_stock_threshold),
         unit_price = COALESCE(NULLIF($6, 0), stock_items.unit_price),
         unit_cost = COALESCE(NULLIF($7, 0), stock_items.unit_cost),
         updated_at = NOW()
       RETURNING id, tenant_id as "tenantId", product_id as "productId", name,
                 stock_quantity as "stockQuantity", low_stock_threshold as "lowStockThreshold",
                 unit_price as "unitPrice", unit_cost as "unitCost", updated_at as "updatedAt"`,
      [tenantId, item.productId, item.name || '', item.stockDelta || 0, item.lowStockThreshold || 0, item.unitPrice || 0, item.unitCost || 0],
    );
    const row = res.rows[0];
    return {
      id: row.id,
      tenantId: row.tenantId,
      productId: row.productId,
      name: row.name,
      stockQuantity: Number(row.stockQuantity) || 0,
      lowStockThreshold: Number(row.lowStockThreshold) || 0,
      unitPrice: Number(row.unitPrice) || 0,
      unitCost: Number(row.unitCost) || 0,
      updatedAt: row.updatedAt,
    };
  }

  async upsertCustomerDebt(tenantId: string, customer: { customerId: string; customerName: string; phone?: string; deltaDebt: number }, client?: pg.PoolClient | null) {
    const key = `${tenantId}:${customer.customerId}`;
    const now = new Date();

    if (this.isMemoryFallback) {
      const existing = this.memoryStore.debts.get(key) || {
        tenantId,
        customerId: customer.customerId,
        customerName: customer.customerName,
        phone: customer.phone,
        debtAmount: 0,
        lastSaleDate: now,
      };

      existing.debtAmount += customer.deltaDebt;
      if (existing.debtAmount < 0) existing.debtAmount = 0;
      if (customer.customerName) existing.customerName = customer.customerName;
      if (customer.phone) existing.phone = customer.phone;
      existing.lastSaleDate = now;

      this.memoryStore.debts.set(key, existing);
      return existing;
    }

    const res = await this.queryWithClient<any>(
      client || null,
      `INSERT INTO customer_debts (tenant_id, customer_id, customer_name, phone, debt_amount, last_sale_date)
       VALUES ($1, $2, $3, $4, GREATEST(0, $5), NOW())
       ON CONFLICT (tenant_id, customer_id)
       DO UPDATE SET
         customer_name = COALESCE(NULLIF($3, ''), customer_debts.customer_name),
         phone = COALESCE($4, customer_debts.phone),
         debt_amount = GREATEST(0, customer_debts.debt_amount + $5),
         last_sale_date = NOW()
       RETURNING id, tenant_id as "tenantId", customer_id as "customerId", customer_name as "customerName",
                 phone, debt_amount as "debtAmount", last_sale_date as "lastSaleDate"`,
      [tenantId, customer.customerId, customer.customerName, customer.phone, customer.deltaDebt],
    );
    const row = res.rows[0];
    return {
      id: row.id,
      tenantId: row.tenantId,
      customerId: row.customerId,
      customerName: row.customerName,
      phone: row.phone,
      debtAmount: Number(row.debtAmount) || 0,
      lastSaleDate: row.lastSaleDate,
    };
  }

  async createAlert(tenantId: string, type: string, severity: 'info' | 'warning' | 'critical', title: string, message: string, client?: pg.PoolClient | null): Promise<AlertRecord> {
    const alert: AlertRecord = {
      id: randomUUID(),
      tenantId,
      type,
      severity,
      title,
      message,
      isRead: false,
      createdAt: new Date(),
    };

    if (this.isMemoryFallback) {
      this.memoryStore.alerts.set(alert.id, alert);
      return alert;
    }

    const res = await this.queryWithClient<any>(
      client || null,
      `INSERT INTO alerts (tenant_id, type, severity, title, message)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, tenant_id as "tenantId", type, severity, title, message, is_read as "isRead", created_at as "createdAt"`,
      [tenantId, type, severity, title, message],
    );
    const row = res.rows[0];
    return {
      ...row,
      isRead: row.isRead === true,
    };
  }

  async getAlerts(tenantId: string, limit = 50): Promise<AlertRecord[]> {
    if (this.isMemoryFallback) {
      const list = Array.from(this.memoryStore.alerts.values())
        .filter((a) => a.tenantId === tenantId)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
        .slice(0, limit);
      return list;
    }
    const res = await this.query<any>(
      'SELECT id, tenant_id as "tenantId", type, severity, title, message, is_read as "isRead", created_at as "createdAt" FROM alerts WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2',
      [tenantId, limit],
    );
    return res.rows.map((r) => ({
      ...r,
      isRead: r.isRead === true,
    }));
  }

  async ackAlert(tenantId: string, alertId: string): Promise<boolean> {
    if (this.isMemoryFallback) {
      const alert = this.memoryStore.alerts.get(alertId);
      if (alert && alert.tenantId === tenantId) {
        alert.isRead = true;
        return true;
      }
      return false;
    }
    const res = await this.query('UPDATE alerts SET is_read = TRUE WHERE tenant_id = $1 AND id = $2', [tenantId, alertId]);
    return res.rowCount > 0;
  }

  async getDailySnapshots(tenantId: string, limit = 30): Promise<DailySnapshotRecord[]> {
    if (this.isMemoryFallback) {
      return Array.from(this.memoryStore.dailySnapshots.values())
        .filter((s) => s.tenantId === tenantId)
        .sort((a, b) => b.snapshotDate.localeCompare(a.snapshotDate))
        .slice(0, limit);
    }
    const res = await this.query<any>(
      `SELECT id, tenant_id as "tenantId", TO_CHAR(snapshot_date, 'YYYY-MM-DD') as "snapshotDate",
              total_sales as "totalSales", total_profit as "totalProfit", sales_count as "salesCount",
              cash_collected as "cashCollected", momo_collected as "momoCollected", credit_issued as "creditIssued",
              last_sync_at as "lastSyncAt"
       FROM daily_snapshots WHERE tenant_id = $1 ORDER BY snapshot_date DESC LIMIT $2`,
      [tenantId, limit],
    );
    return res.rows.map((r) => ({
      ...r,
      totalSales: Number(r.totalSales) || 0,
      totalProfit: Number(r.totalProfit) || 0,
      salesCount: Number(r.salesCount) || 0,
      cashCollected: Number(r.cashCollected) || 0,
      momoCollected: Number(r.momoCollected) || 0,
      creditIssued: Number(r.creditIssued) || 0,
    }));
  }

  async getStockItems(tenantId: string): Promise<StockItemRecord[]> {
    if (this.isMemoryFallback) {
      return Array.from(this.memoryStore.stock.values()).filter((s) => s.tenantId === tenantId);
    }
    const res = await this.query<any>(
      `SELECT id, tenant_id as "tenantId", product_id as "productId", name,
              stock_quantity as "stockQuantity", low_stock_threshold as "lowStockThreshold",
              unit_price as "unitPrice", unit_cost as "unitCost", updated_at as "updatedAt"
       FROM stock_items WHERE tenant_id = $1 ORDER BY name ASC`,
      [tenantId],
    );
    return res.rows.map((r) => ({
      ...r,
      stockQuantity: Number(r.stockQuantity) || 0,
      lowStockThreshold: Number(r.lowStockThreshold) || 0,
      unitPrice: Number(r.unitPrice) || 0,
      unitCost: Number(r.unitCost) || 0,
    }));
  }

  async getCustomerDebts(tenantId: string): Promise<CustomerDebtRecord[]> {
    if (this.isMemoryFallback) {
      return Array.from(this.memoryStore.debts.values())
        .filter((d) => d.tenantId === tenantId && d.debtAmount > 0)
        .sort((a, b) => b.debtAmount - a.debtAmount);
    }
    const res = await this.query<any>(
      `SELECT id, tenant_id as "tenantId", customer_id as "customerId", customer_name as "customerName",
              phone, debt_amount as "debtAmount", last_sale_date as "lastSaleDate"
       FROM customer_debts WHERE tenant_id = $1 AND debt_amount > 0 ORDER BY debt_amount DESC`,
      [tenantId],
    );
    return res.rows.map((r) => ({
      ...r,
      debtAmount: Number(r.debtAmount) || 0,
    }));
  }

  async getRecentSales(tenantId: string, limit = 20): Promise<SaleRecord[]> {
    if (this.isMemoryFallback) {
      return Array.from(this.memoryStore.sales.values())
        .filter((s) => s.tenantId === tenantId)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
        .slice(0, limit);
    }
    const res = await this.query<any>(
      `SELECT id, tenant_id as "tenantId", sale_id as "saleId", reference, customer_name as "customerName",
              customer_id as "customerId", total_amount as "totalAmount", amount_paid as "amountPaid", profit,
              payment_method_index as "paymentMethodIndex", mobile_money_provider as "mobileMoneyProvider",
              is_cancelled as "isCancelled", created_at as "createdAt"
       FROM sales_records WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return res.rows.map((r) => ({
      ...r,
      totalAmount: Number(r.totalAmount) || 0,
      amountPaid: Number(r.amountPaid) || 0,
      profit: Number(r.profit) || 0,
      paymentMethodIndex: Number(r.paymentMethodIndex) || 0,
      isCancelled: r.isCancelled === true,
    }));
  }

  async getRecentExpenses(tenantId: string, limit = 20): Promise<ExpenseRecord[]> {
    if (this.isMemoryFallback) {
      return Array.from(this.memoryStore.expenses.values())
        .filter((e) => e.tenantId === tenantId)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
        .slice(0, limit);
    }
    const res = await this.query<any>(
      `SELECT id, tenant_id as "tenantId", expense_id as "expenseId", reference,
              category_index as "categoryIndex", amount, payment_method_index as "paymentMethodIndex",
              description, created_at as "createdAt"
       FROM expenses WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return res.rows.map((r) => ({
      ...r,
      amount: Number(r.amount) || 0,
      categoryIndex: Number(r.categoryIndex) || 0,
      paymentMethodIndex: Number(r.paymentMethodIndex) || 0,
    }));
  }

  async getRecentCashMovements(tenantId: string, limit = 20): Promise<CashMovementRecord[]> {
    if (this.isMemoryFallback) {
      return Array.from(this.memoryStore.cashMovements.values())
        .filter((m) => m.tenantId === tenantId)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
        .slice(0, limit);
    }
    const res = await this.query<any>(
      `SELECT id, tenant_id as "tenantId", movement_id as "movementId", reference,
              description, amount, type_index as "typeIndex", payment_method_index as "paymentMethodIndex",
              created_at as "createdAt"
       FROM cash_movements WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [tenantId, limit],
    );
    return res.rows.map((r) => ({
      ...r,
      amount: Number(r.amount) || 0,
      typeIndex: Number(r.typeIndex) || 0,
      paymentMethodIndex: Number(r.paymentMethodIndex) || 0,
    }));
  }

  async getTreasurySummary(tenantId: string): Promise<{
    totalCashSales: number;
    totalMomoSales: number;
    totalCashExpenses: number;
    totalCashIn: number;
    totalCashOut: number;
    openingFund: number;
  }> {
    if (this.isMemoryFallback) {
      let totalCashSales = 0;
      let totalMomoSales = 0;
      for (const snap of this.memoryStore.dailySnapshots.values()) {
        if (snap.tenantId === tenantId) {
          totalCashSales += Number(snap.cashCollected) || 0;
          totalMomoSales += Number(snap.momoCollected) || 0;
        }
      }
      let totalCashExpenses = 0;
      for (const exp of this.memoryStore.expenses.values()) {
        if (exp.tenantId === tenantId && exp.paymentMethodIndex === 0) {
          totalCashExpenses += Number(exp.amount) || 0;
        }
      }
      let totalCashIn = 0;
      let totalCashOut = 0;
      for (const mvt of this.memoryStore.cashMovements.values()) {
        if (mvt.tenantId === tenantId) {
          if (mvt.typeIndex === 0) totalCashIn += Number(mvt.amount) || 0;
          else totalCashOut += Number(mvt.amount) || 0;
        }
      }
      const shop = this.memoryStore.shops.get(tenantId);
      const openingFund = Number(shop?.openingFund) || 0;
      return { totalCashSales, totalMomoSales, totalCashExpenses, totalCashIn, totalCashOut, openingFund };
    }

    const res = await this.query(
      `SELECT
        COALESCE((SELECT SUM(cash_collected) FROM daily_snapshots WHERE tenant_id = $1), 0) as "totalCashSales",
        COALESCE((SELECT SUM(momo_collected) FROM daily_snapshots WHERE tenant_id = $1), 0) as "totalMomoSales",
        COALESCE((SELECT SUM(amount) FROM expenses WHERE tenant_id = $1 AND payment_method_index = 0), 0) as "totalCashExpenses",
        COALESCE((SELECT SUM(amount) FROM cash_movements WHERE tenant_id = $1 AND type_index = 0), 0) as "totalCashIn",
        COALESCE((SELECT SUM(amount) FROM cash_movements WHERE tenant_id = $1 AND type_index = 1), 0) as "totalCashOut",
        COALESCE((SELECT opening_fund FROM shops WHERE id = $1), 0) as "openingFund"`,
      [tenantId],
    );
    const row = res.rows[0] || {};
    return {
      totalCashSales: Number(row.totalCashSales) || 0,
      totalMomoSales: Number(row.totalMomoSales) || 0,
      totalCashExpenses: Number(row.totalCashExpenses) || 0,
      totalCashIn: Number(row.totalCashIn) || 0,
      totalCashOut: Number(row.totalCashOut) || 0,
      openingFund: Number(row.openingFund) || 0,
    };
  }
}
