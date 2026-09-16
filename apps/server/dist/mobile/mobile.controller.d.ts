import { MobileService } from './mobile.service.js';
export declare class MobileController {
    private readonly mobileService;
    constructor(mobileService: MobileService);
    getDashboard(req: any): Promise<{
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
    getSales(req: any, period?: string): Promise<{
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
    getTreasury(req: any): Promise<{
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
    getStock(req: any): Promise<{
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
    getReceivables(req: any): Promise<{
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
    getAlerts(req: any): Promise<{
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
    ackAlert(req: any, id: string): Promise<{
        success: boolean;
    }>;
    getProfile(req: any): Promise<{
        id: string;
        businessName: string;
        licenseKey: string;
        currency: string;
        phone: string | undefined;
        isActive: boolean;
        createdAt: string;
    }>;
}
