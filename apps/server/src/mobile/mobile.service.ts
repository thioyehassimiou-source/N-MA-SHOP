import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service.js';

@Injectable()
export class MobileService {
  private readonly logger = new Logger(MobileService.name);

  constructor(private readonly db: DatabaseService) {}

  async getDashboard(tenantId: string) {
    const shop = await this.db.findShopById(tenantId);
    const todayStr = new Date().toISOString().split('T')[0];
    const yesterdayDate = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const yesterdayStr = yesterdayDate.toISOString().split('T')[0];

    const snapshots = await this.db.getDailySnapshots(tenantId, 10);
    const todaySnap = snapshots.find((s) => s.snapshotDate === todayStr) || {
      totalSales: 0,
      totalProfit: 0,
      salesCount: 0,
      cashCollected: 0,
      momoCollected: 0,
      creditIssued: 0,
      lastSyncAt: null,
    };
    const yesterdaySnap = snapshots.find((s) => s.snapshotDate === yesterdayStr) || {
      totalSales: 0,
      totalProfit: 0,
      salesCount: 0,
      cashCollected: 0,
      momoCollected: 0,
      creditIssued: 0,
    };

    const alerts = await this.db.getAlerts(tenantId, 10);
    const unreadAlertsCount = alerts.filter((a) => !a.isRead).length;

    const stock = await this.db.getStockItems(tenantId);
    const lowStockCount = stock.filter((s) => s.stockQuantity > 0 && s.stockQuantity <= s.lowStockThreshold).length;
    const outOfStockCount = stock.filter((s) => s.stockQuantity <= 0).length;

    const debts = await this.db.getCustomerDebts(tenantId);
    const totalReceivables = debts.reduce((acc, d) => acc + (Number(d.debtAmount) || 0), 0);

    return {
      shop: {
        id: shop?.id || tenantId,
        name: shop?.businessName || 'Boutique',
        currency: shop?.currency || 'GNF',
        lastSyncAt: todaySnap.lastSyncAt ? new Date(todaySnap.lastSyncAt).toISOString() : null,
      },
      today: {
        totalSales: Number(todaySnap.totalSales) || 0,
        totalProfit: Number(todaySnap.totalProfit) || 0,
        salesCount: Number(todaySnap.salesCount) || 0,
        cashCollected: Number(todaySnap.cashCollected) || 0,
        momoCollected: Number(todaySnap.momoCollected) || 0,
        creditIssued: Number(todaySnap.creditIssued) || 0,
      },
      yesterday: {
        totalSales: Number(yesterdaySnap.totalSales) || 0,
        salesCount: Number(yesterdaySnap.salesCount) || 0,
      },
      stock: {
        lowStockCount,
        outOfStockCount,
      },
      receivables: {
        totalAmount: totalReceivables,
        debtorsCount: debts.length,
      },
      alerts: {
        unreadCount: unreadAlertsCount,
        recent: alerts.slice(0, 3),
      },
      serverTime: new Date().toISOString(),
    };
  }

  async getSales(tenantId: string, period = 'today') {
    const days = period === '30d' ? 30 : period === '7d' ? 7 : 1;
    const snapshots = await this.db.getDailySnapshots(tenantId, days);
    const recentSales = await this.db.getRecentSales(tenantId, 25);

    let totalSales = 0;
    let totalProfit = 0;
    let salesCount = 0;
    let cashCollected = 0;
    let momoCollected = 0;
    let creditIssued = 0;

    for (const snap of snapshots) {
      totalSales += Number(snap.totalSales) || 0;
      totalProfit += Number(snap.totalProfit) || 0;
      salesCount += Number(snap.salesCount) || 0;
      cashCollected += Number(snap.cashCollected) || 0;
      momoCollected += Number(snap.momoCollected) || 0;
      creditIssued += Number(snap.creditIssued) || 0;
    }

    return {
      period,
      summary: {
        totalSales,
        totalProfit,
        salesCount,
        averageTicket: salesCount > 0 ? Math.round(totalSales / salesCount) : 0,
        cashCollected,
        momoCollected,
        creditIssued,
      },
      timeline: snapshots.map((s) => ({
        date: s.snapshotDate,
        sales: Number(s.totalSales) || 0,
        profit: Number(s.totalProfit) || 0,
        count: Number(s.salesCount) || 0,
      })),
      recentSales: recentSales.map((s) => ({
        saleId: s.saleId,
        reference: s.reference,
        customerName: s.customerName || 'Client standard',
        totalAmount: Number(s.totalAmount) || 0,
        amountPaid: Number(s.amountPaid) || 0,
        paymentMethodIndex: Number(s.paymentMethodIndex) || 0,
        mobileMoneyProvider: s.mobileMoneyProvider,
        createdAt: new Date(s.createdAt).toISOString(),
      })),
    };
  }

  async getTreasury(tenantId: string) {
    const todayStr = new Date().toISOString().split('T')[0];
    const snapshots = await this.db.getDailySnapshots(tenantId, 30);
    const todaySnap = snapshots.find((s) => s.snapshotDate === todayStr);

    const expenses = await this.db.getRecentExpenses(tenantId, 20);
    const cashMovements = await this.db.getRecentCashMovements(tenantId, 20);

    // Calcul exact et non-tronqué de la trésorerie via getTreasurySummary
    const summary = await this.db.getTreasurySummary(tenantId);
    const theoreticalCashInHand = Math.max(
      0,
      summary.openingFund + summary.totalCashSales + summary.totalCashIn - summary.totalCashOut - summary.totalCashExpenses,
    );

    return {
      theoreticalCashInHand,
      openingFund: summary.openingFund,
      totalCashCollected: summary.totalCashSales,
      totalCashExpenses: summary.totalCashExpenses,
      momoCollectedToday: Number(todaySnap?.momoCollected) || 0,
      cashCollectedToday: Number(todaySnap?.cashCollected) || 0,
      expensesToday: expenses
        .filter((e) => new Date(e.createdAt).toISOString().split('T')[0] === todayStr)
        .reduce((acc, e) => acc + (Number(e.amount) || 0), 0),
      recentExpenses: expenses.slice(0, 10).map((e) => ({
        expenseId: e.expenseId,
        reference: e.reference,
        amount: Number(e.amount) || 0,
        categoryIndex: Number(e.categoryIndex) || 0,
        paymentMethodIndex: Number(e.paymentMethodIndex) || 0,
        description: e.description,
        createdAt: new Date(e.createdAt).toISOString(),
      })),
      recentMovements: cashMovements.slice(0, 10).map((m) => ({
        movementId: m.movementId,
        reference: m.reference,
        description: m.description,
        amount: Number(m.amount) || 0,
        typeIndex: Number(m.typeIndex) || 0,
        paymentMethodIndex: Number(m.paymentMethodIndex) || 0,
        createdAt: new Date(m.createdAt).toISOString(),
      })),
    };
  }

  async getStock(tenantId: string) {
    const items = await this.db.getStockItems(tenantId);
    let totalInventoryValue = 0;
    let lowCount = 0;
    let outCount = 0;

    const formattedItems = items.map((i) => {
      const qty = Number(i.stockQuantity) || 0;
      const threshold = Number(i.lowStockThreshold) || 5;
      const cost = Number(i.unitCost) || 0;
      const price = Number(i.unitPrice) || 0;
      totalInventoryValue += qty * cost;

      let status: 'ok' | 'low' | 'out' = 'ok';
      if (qty <= 0) {
        status = 'out';
        outCount++;
      } else if (qty <= threshold) {
        status = 'low';
        lowCount++;
      }

      return {
        productId: i.productId,
        name: i.name || 'Produit',
        quantity: qty,
        lowStockThreshold: threshold,
        unitPrice: price,
        unitCost: cost,
        status,
        updatedAt: i.updatedAt ? new Date(i.updatedAt).toISOString() : null,
      };
    });

    return {
      totalProducts: items.length,
      totalInventoryValue,
      lowStockCount: lowCount,
      outOfStockCount: outCount,
      items: formattedItems,
    };
  }

  async getReceivables(tenantId: string) {
    const debts = await this.db.getCustomerDebts(tenantId);
    const totalReceivables = debts.reduce((acc, d) => acc + (Number(d.debtAmount) || 0), 0);

    return {
      totalReceivables,
      customersCount: debts.length,
      debtors: debts.map((d) => ({
        customerId: d.customerId,
        customerName: d.customerName || 'Client',
        phone: d.phone,
        debtAmount: Number(d.debtAmount) || 0,
        lastSaleDate: d.lastSaleDate ? new Date(d.lastSaleDate).toISOString() : null,
      })),
    };
  }

  async getAlerts(tenantId: string) {
    const alerts = await this.db.getAlerts(tenantId, 50);
    return {
      alerts: alerts.map((a) => ({
        id: a.id,
        type: a.type,
        severity: a.severity,
        title: a.title,
        message: a.message,
        isRead: a.isRead,
        createdAt: new Date(a.createdAt).toISOString(),
      })),
    };
  }

  async ackAlert(tenantId: string, alertId: string) {
    const success = await this.db.ackAlert(tenantId, alertId);
    return { success };
  }

  async getProfile(tenantId: string) {
    const shop = await this.db.findShopById(tenantId);
    if (!shop) throw new NotFoundException('Boutique introuvable.');

    return {
      id: shop.id,
      businessName: shop.businessName,
      licenseKey: shop.licenseKey,
      currency: shop.currency,
      phone: shop.phone,
      isActive: shop.isActive,
      createdAt: new Date(shop.createdAt).toISOString(),
    };
  }
}
