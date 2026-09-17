import { OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import pg from 'pg';
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
    snapshotDate: string;
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
    typeIndex: number;
    paymentMethodIndex: number;
    createdAt: Date;
}
export declare class DatabaseService implements OnModuleInit, OnModuleDestroy {
    private readonly logger;
    private pool;
    private isMemoryFallback;
    memoryStore: {
        shops: Map<string, ShopRecord>;
        devices: Map<string, DeviceRecord>;
        pairingTokens: Map<string, {
            tenantId: string;
            shopName: string;
            currency: string;
            expiresAt: Date;
            consumed: boolean;
        }>;
        syncEvents: Set<string>;
        dailySnapshots: Map<string, DailySnapshotRecord>;
        stock: Map<string, StockItemRecord>;
        debts: Map<string, CustomerDebtRecord>;
        alerts: Map<string, AlertRecord>;
        sales: Map<string, SaleRecord>;
        expenses: Map<string, ExpenseRecord>;
        cashMovements: Map<string, CashMovementRecord>;
    };
    constructor();
    onModuleInit(): Promise<void>;
    onModuleDestroy(): Promise<void>;
    cleanAllForTesting(): Promise<void>;
    private initPostgresSchema;
    query<T = any>(sql: string, params?: any[]): Promise<QueryResult<T>>;
    withTransaction<T>(callback: (client: pg.PoolClient | null) => Promise<T>): Promise<T>;
    queryWithClient<T = any>(client: pg.PoolClient | null, sql: string, params?: any[]): Promise<QueryResult<T>>;
    get isFallback(): boolean;
    findShopByLicense(licenseKey: string): Promise<ShopRecord | null>;
    findShopById(id: string): Promise<ShopRecord | null>;
    seedDemoStoreForTenant(tenantId: string): void;
    saveCaisseSecret(shopId: string, caisseSecret: string): Promise<void>;
    upsertShop(licenseKey: string, businessName: string, currency?: string): Promise<ShopRecord>;
    savePairingToken(token: string, tenantId: string, shopName: string, currency?: string, expiresAt?: Date): Promise<void>;
    getPairingToken(token: string): Promise<any>;
    consumePairingToken(token: string): Promise<void>;
    findDevice(deviceId: string): Promise<DeviceRecord | null>;
    saveDevice(device: {
        tenantId: string;
        deviceId: string;
        deviceName: string;
        pinHash: string;
        refreshTokenHash?: string;
    }): Promise<DeviceRecord>;
    registerMobileShopAndDevice(params: {
        licenseKey: string;
        shopName: string;
        currency: string;
        deviceId: string;
        deviceName: string;
        pinHash: string;
        refreshTokenHash: string;
    }): Promise<{
        shop: ShopRecord;
        device: DeviceRecord;
    }>;
    updateDeviceLastSeen(deviceId: string): Promise<void>;
    updateDeviceRefreshToken(deviceId: string, refreshTokenHash: string): Promise<void>;
    updateDeviceFailedPin(deviceId: string, failedCount: number, lockoutUntil: Date | null): Promise<void>;
    resetDeviceLockout(deviceId: string): Promise<void>;
    hasSyncEvent(tenantId: string, eventId: string, client?: pg.PoolClient | null): Promise<boolean>;
    saveSyncEvent(tenantId: string, eventId: string, eventType: string, sequenceNumber?: number, machineId?: string, payload?: any, client?: pg.PoolClient | null): Promise<void>;
    updateDailySnapshot(tenantId: string, date: string, delta: {
        totalSales?: number;
        totalProfit?: number;
        salesCount?: number;
        cashCollected?: number;
        momoCollected?: number;
        creditIssued?: number;
    }, client?: pg.PoolClient | null): Promise<DailySnapshotRecord>;
    saveSaleRecord(sale: SaleRecord, client?: pg.PoolClient | null): Promise<void>;
    getSaleRecord(tenantId: string, saleId: string, client?: pg.PoolClient | null): Promise<SaleRecord | null>;
    markSaleCancelled(tenantId: string, saleId: string, client?: pg.PoolClient | null): Promise<void>;
    saveExpenseRecord(expense: ExpenseRecord, client?: pg.PoolClient | null): Promise<void>;
    saveCashMovementRecord(movement: CashMovementRecord, client?: pg.PoolClient | null): Promise<void>;
    upsertStockItem(tenantId: string, item: {
        productId: string;
        name: string;
        stockDelta?: number;
        lowStockThreshold?: number;
        unitPrice?: number;
        unitCost?: number;
    }, client?: pg.PoolClient | null): Promise<StockItemRecord | {
        id: any;
        tenantId: any;
        productId: any;
        name: any;
        stockQuantity: number;
        lowStockThreshold: number;
        unitPrice: number;
        unitCost: number;
        updatedAt: any;
    }>;
    upsertCustomerDebt(tenantId: string, customer: {
        customerId: string;
        customerName: string;
        phone?: string;
        deltaDebt: number;
    }, client?: pg.PoolClient | null): Promise<CustomerDebtRecord | {
        id: any;
        tenantId: any;
        customerId: any;
        customerName: any;
        phone: any;
        debtAmount: number;
        lastSaleDate: any;
    }>;
    createAlert(tenantId: string, type: string, severity: 'info' | 'warning' | 'critical', title: string, message: string, client?: pg.PoolClient | null): Promise<AlertRecord>;
    getAlerts(tenantId: string, limit?: number): Promise<AlertRecord[]>;
    ackAlert(tenantId: string, alertId: string): Promise<boolean>;
    getDailySnapshots(tenantId: string, limit?: number): Promise<DailySnapshotRecord[]>;
    getStockItems(tenantId: string): Promise<StockItemRecord[]>;
    getCustomerDebts(tenantId: string): Promise<CustomerDebtRecord[]>;
    getRecentSales(tenantId: string, limit?: number): Promise<SaleRecord[]>;
    getRecentExpenses(tenantId: string, limit?: number): Promise<ExpenseRecord[]>;
    getRecentCashMovements(tenantId: string, limit?: number): Promise<CashMovementRecord[]>;
    getTreasurySummary(tenantId: string): Promise<{
        totalCashSales: number;
        totalMomoSales: number;
        totalCashExpenses: number;
        totalCashIn: number;
        totalCashOut: number;
        openingFund: number;
    }>;
}
