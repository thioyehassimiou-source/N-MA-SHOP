import { DatabaseService } from '../database/database.service.js';
export declare class MobileService {
    private readonly db;
    private readonly logger;
    constructor(db: DatabaseService);
    getDashboard(tenantId: string): Promise<{
        shop: {
            id: string;
            name: string;
            currency: string;
            lastSyncAt: string | null;
        };
        today: {
            totalSales: number;
            totalProfit: number;
            salesCount: number;
            cashCollected: number;
            momoCollected: number;
            creditIssued: number;
        };
        yesterday: {
            totalSales: number;
            salesCount: number;
        };
        stock: {
            lowStockCount: number;
            outOfStockCount: number;
        };
        receivables: {
            totalAmount: number;
            debtorsCount: number;
        };
        alerts: {
            unreadCount: number;
            recent: import("../database/database.service.js").AlertRecord[];
        };
        serverTime: string;
    }>;
    getSales(tenantId: string, period?: string): Promise<{
        period: string;
        summary: {
            totalSales: number;
            totalProfit: number;
            salesCount: number;
            averageTicket: number;
            cashCollected: number;
            momoCollected: number;
            creditIssued: number;
        };
        timeline: {
            date: string;
            sales: number;
            profit: number;
            count: number;
        }[];
        recentSales: {
            saleId: string;
            reference: string;
            customerName: string;
            totalAmount: number;
            amountPaid: number;
            paymentMethodIndex: number;
            mobileMoneyProvider: string | undefined;
            createdAt: string;
        }[];
    }>;
    getTreasury(tenantId: string): Promise<{
        theoreticalCashInHand: number;
        openingFund: number;
        totalCashCollected: number;
        totalCashExpenses: number;
        momoCollectedToday: number;
        cashCollectedToday: number;
        expensesToday: number;
        recentExpenses: {
            expenseId: string;
            reference: string;
            amount: number;
            categoryIndex: number;
            paymentMethodIndex: number;
            description: string | undefined;
            createdAt: string;
        }[];
        recentMovements: {
            movementId: string;
            reference: string;
            description: string;
            amount: number;
            typeIndex: number;
            paymentMethodIndex: number;
            createdAt: string;
        }[];
    }>;
    getStock(tenantId: string): Promise<{
        totalProducts: number;
        totalInventoryValue: number;
        lowStockCount: number;
        outOfStockCount: number;
        items: {
            productId: string;
            name: string;
            quantity: number;
            lowStockThreshold: number;
            unitPrice: number;
            unitCost: number;
            status: "ok" | "low" | "out";
            updatedAt: string | null;
        }[];
    }>;
    getReceivables(tenantId: string): Promise<{
        totalReceivables: number;
        customersCount: number;
        debtors: {
            customerId: string;
            customerName: string;
            phone: string | undefined;
            debtAmount: number;
            lastSaleDate: string | null;
        }[];
    }>;
    getAlerts(tenantId: string): Promise<{
        alerts: {
            id: string;
            type: string;
            severity: "info" | "warning" | "critical";
            title: string;
            message: string;
            isRead: boolean;
            createdAt: string;
        }[];
    }>;
    ackAlert(tenantId: string, alertId: string): Promise<{
        success: boolean;
    }>;
    getProfile(tenantId: string): Promise<{
        id: string;
        businessName: string;
        licenseKey: string;
        currency: string;
        phone: string | undefined;
        isActive: boolean;
        createdAt: string;
    }>;
}
