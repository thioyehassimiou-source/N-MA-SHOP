import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../database/database.service.js';
import { B2StorageService } from './b2-storage.service.js';
import { SyncBatchDto } from './sync.dto.js';
import type * as pg from 'pg';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly b2Storage: B2StorageService,
  ) {}

  async processBatch(dto: SyncBatchDto) {
    let shop = await this.db.findShopByLicense(dto.licenseKey);
    if (!shop) {
      throw new Error('Boutique non reconnue ou non provisionnée.');
    }

    let processedCount = 0;
    let skippedCount = 0;

    for (const event of dto.events) {
      try {
        await this.db.withTransaction(async (client) => {
          const alreadyProcessed = await this.db.hasSyncEvent(shop!.id, event.eventId, client);
          if (alreadyProcessed) {
            skippedCount++;
            return;
          }

          const seq = Number(event.sequenceNumber ?? (event.data && event.data.sequenceNumber)) || 0;
          const machineId = dto.machineId || '';

          // 1. Process the business event first
          await this.handleEvent(shop!.id, event, client);

          // 2. Mark event as processed (inside same transaction)
          await this.db.saveSyncEvent(shop!.id, event.eventId, event.entityType, seq, machineId, event.data, client);
          processedCount++;
        });
      } catch (err) {
        this.logger.error(`Erreur lors du traitement transactionnel de l'événement ${event.eventId} (${event.entityType}): ${err}`);
      }
    }

    this.logger.log(`Lot synchronisé pour boutique "${shop.businessName}": ${processedCount} traités, ${skippedCount} ignorés.`);

    return {
      success: true,
      processedCount,
      skippedCount,
      serverTime: new Date().toISOString(),
    };
  }

  private async handleEvent(
    tenantId: string,
    event: { eventId: string; entityType: string; entityId: string; action?: string; timestamp: string; data: Record<string, any> },
    client?: pg.PoolClient | null,
  ) {
    const data = event.data || {};
    const eventDate = data.date ? new Date(data.date) : new Date(event.timestamp);
    const dateStr = eventDate.toISOString().split('T')[0];

    switch (event.entityType) {
      case 'sale': {
        const saleId = data.saleId || event.entityId;
        const isCancellation = event.action === 'cancel' || data.isCancelled === true;

        if (isCancellation) {
          const existingSale = await this.db.getSaleRecord(tenantId, saleId, client);
          if (existingSale && existingSale.isCancelled) {
            this.logger.warn(`Vente ${saleId} déjà annulée pour le tenant ${tenantId}. Ignorée.`);
            break;
          }

          if (!existingSale) {
            // Out-of-order: cancel arrived BEFORE create
            this.logger.warn(`Vente ${saleId} annulée avant création (out-of-order). Création d'un tombstone.`);
            await this.db.saveSaleRecord({
              id: `sale-${saleId}`,
              tenantId,
              saleId,
              reference: data.reference || `VENTE-${saleId}`,
              customerName: data.customerName,
              customerId: data.customerId,
              totalAmount: Number(data.totalAmount) || 0,
              amountPaid: Number(data.amountPaid) || 0,
              profit: 0,
              paymentMethodIndex: Number(data.paymentMethodIndex) || 0,
              mobileMoneyProvider: data.mobileMoneyProvider,
              isCancelled: true,
              isPending: true,
              lines: Array.isArray(data.lines) ? data.lines : [],
              createdAt: eventDate,
            }, client);

            await this.db.createAlert(
              tenantId,
              'sale_cancelled',
              'warning',
              `Annulation anticipée : ${data.reference || saleId}`,
              `Une annulation de vente est arrivée avant sa création. Tombstone enregistré.`,
              client,
            );
            break;
          }

          const totalAmount = existingSale.totalAmount;
          const amountPaid = existingSale.amountPaid;
          const profit = existingSale.profit;
          const paymentMethodIndex = existingSale.paymentMethodIndex;
          const lines = (existingSale.lines && existingSale.lines.length > 0) ? existingSale.lines : (Array.isArray(data.lines) ? data.lines : []);
          const customerId = existingSale.customerId || data.customerId;
          const reference = existingSale.reference || data.reference || `VENTE-${saleId}`;

          const cash = paymentMethodIndex === 0 ? amountPaid : 0;
          const momo = paymentMethodIndex === 1 ? amountPaid : 0;
          const credit = totalAmount > amountPaid ? totalAmount - amountPaid : 0;

          // 1. Marquer la vente annulée
          await this.db.markSaleCancelled(tenantId, saleId, client);

          // 2. Si la vente n'était pas en attente (déjà comptée), corriger les agrégats
          if (!existingSale.isPending) {
            await this.db.updateDailySnapshot(tenantId, dateStr, {
              totalSales: -totalAmount,
              totalProfit: -profit,
              salesCount: -1,
              cashCollected: -cash,
              momoCollected: -momo,
              creditIssued: -credit,
            }, client);

            // 3. Annuler la dette client si à crédit
            if (credit > 0 && customerId) {
              await this.db.upsertCustomerDebt(tenantId, {
                customerId,
                customerName: existingSale.customerName || data.customerName || 'Client',
                deltaDebt: -credit,
              }, client);
            }

            // 4. Réintégrer le stock
            for (const line of lines) {
              if (line.productId) {
                await this.db.upsertStockItem(tenantId, {
                  productId: line.productId,
                  name: line.label || 'Produit',
                  stockDelta: Number(line.quantity) || 0,
                }, client);
              }
            }
          }

          // 5. Alerte d'annulation de vente
          await this.db.createAlert(
            tenantId,
            'sale_cancelled',
            'warning',
            `Annulation de vente : ${reference}`,
            `La vente de ${totalAmount.toLocaleString('fr-FR')} GNF a été annulée. Stock et caisse corrigés.`,
            client,
          );
          break;
        }

        // Création de vente normale : vérifier si un tombstone existe déjà
        const existingSale = await this.db.getSaleRecord(tenantId, saleId, client);
        if (existingSale && existingSale.isCancelled) {
          this.logger.warn(`Vente ${saleId} créée alors qu'elle a déjà été annulée en amont (tombstone). Mise à jour des métadonnées sans impacter les agrégats.`);
          await this.db.saveSaleRecord({
            id: existingSale.id || `sale-${saleId}`,
            tenantId,
            saleId,
            reference: data.reference || existingSale.reference || 'VENTE',
            customerName: data.customerName || existingSale.customerName,
            customerId: data.customerId || existingSale.customerId,
            totalAmount: Number(data.totalAmount) || existingSale.totalAmount || 0,
            amountPaid: Number(data.amountPaid) || existingSale.amountPaid || 0,
            profit: 0,
            paymentMethodIndex: Number(data.paymentMethodIndex) || existingSale.paymentMethodIndex || 0,
            mobileMoneyProvider: data.mobileMoneyProvider || existingSale.mobileMoneyProvider,
            isCancelled: true,
            isPending: false,
            lines: Array.isArray(data.lines) && data.lines.length > 0 ? data.lines : existingSale.lines,
            createdAt: eventDate,
          }, client);
          break;
        }

        const reference = data.reference || 'VENTE';
        const customerName = data.customerName;
        const customerId = data.customerId;
        const totalAmount = Number(data.totalAmount) || 0;
        const amountPaid = Number(data.amountPaid) || 0;
        const paymentMethodIndex = Number(data.paymentMethodIndex) || 0;
        const mobileMoneyProvider = data.mobileMoneyProvider;
        const lines = Array.isArray(data.lines) ? data.lines : [];

        // Calcul de la marge / bénéfice
        const profit = lines.reduce((acc: number, l: any) => {
          const q = Number(l.quantity) || 0;
          const p = Number(l.unitPrice) || 0;
          const c = Number(l.unitCost) || 0;
          return acc + q * (p - c);
        }, 0);

        const cash = paymentMethodIndex === 0 ? amountPaid : 0;
        const momo = paymentMethodIndex === 1 ? amountPaid : 0;
        const credit = totalAmount > amountPaid ? totalAmount - amountPaid : 0;

        await this.db.saveSaleRecord({
          id: `sale-${saleId}`,
          tenantId,
          saleId,
          reference,
          customerName,
          customerId,
          totalAmount,
          amountPaid,
          profit,
          paymentMethodIndex,
          mobileMoneyProvider,
          isCancelled: false,
          isPending: false,
          lines,
          createdAt: eventDate,
        }, client);

        await this.db.updateDailySnapshot(tenantId, dateStr, {
          totalSales: totalAmount,
          totalProfit: profit,
          salesCount: 1,
          cashCollected: cash,
          momoCollected: momo,
          creditIssued: credit,
        }, client);

        if (credit > 0 && customerId) {
          await this.db.upsertCustomerDebt(tenantId, {
            customerId,
            customerName: customerName || 'Client à crédit',
            deltaDebt: credit,
          }, client);
        }

        // Déduction de stock et alertes
        for (const line of lines) {
          if (line.productId) {
            const stockItem = await this.db.upsertStockItem(tenantId, {
              productId: line.productId,
              name: line.label || 'Produit',
              stockDelta: -(Number(line.quantity) || 0),
              unitPrice: Number(line.unitPrice) || 0,
              unitCost: Number(line.unitCost) || 0,
            }, client);

            if (stockItem.stockQuantity <= stockItem.lowStockThreshold) {
              await this.db.createAlert(
                tenantId,
                'low_stock',
                stockItem.stockQuantity <= 0 ? 'critical' : 'warning',
                `Alerte Stock : ${stockItem.name}`,
                stockItem.stockQuantity <= 0
                  ? `Rupture totale ! Le stock est à 0.`
                  : `Stock critique : il ne reste que ${stockItem.stockQuantity} unité(s).`,
                client,
              );
            }
          }
        }

        // Alerte grande vente (>= 2 000 000 GNF)
        if (totalAmount >= 2000000) {
          await this.db.createAlert(
            tenantId,
            'large_sale',
            'info',
            `Vente importante : ${totalAmount.toLocaleString('fr-FR')} GNF`,
            `Réf ${reference} enregistrée par la caisse.`,
            client,
          );
        }
        break;
      }

      case 'creditPayment': {
        const customerId = data.customerId;
        const amount = Number(data.amount) || 0;
        const paymentMethodIndex = Number(data.paymentMethodIndex) || 0;
        const cash = paymentMethodIndex === 0 ? amount : 0;
        const momo = paymentMethodIndex === 1 ? amount : 0;

        if (customerId) {
          await this.db.upsertCustomerDebt(tenantId, {
            customerId,
            customerName: '',
            deltaDebt: -amount,
          }, client);
        }

        await this.db.updateDailySnapshot(tenantId, dateStr, {
          cashCollected: cash,
          momoCollected: momo,
        }, client);

        await this.db.createAlert(
          tenantId,
          'credit_payment',
          'info',
          `Règlement de dette : ${amount.toLocaleString('fr-FR')} GNF`,
          `Un paiement de créance a été encaissé.`,
          client,
        );
        break;
      }

      case 'expense': {
        const expenseId = data.expenseId || event.entityId;
        const reference = data.reference || 'DEP';
        const categoryIndex = Number(data.categoryIndex) || 0;
        const amount = Number(data.amount) || 0;
        const paymentMethodIndex = Number(data.paymentMethodIndex) || 0;
        const description = data.description || '';

        await this.db.saveExpenseRecord({
          id: `exp-${expenseId}`,
          tenantId,
          expenseId,
          reference,
          categoryIndex,
          amount,
          paymentMethodIndex,
          description,
          createdAt: eventDate,
        }, client);

        if (amount >= 500000) {
          await this.db.createAlert(
            tenantId,
            'large_expense',
            'warning',
            `Dépense importante : ${amount.toLocaleString('fr-FR')} GNF`,
            `Motif : ${description || reference}`,
            client,
          );
        }
        break;
      }

      case 'cash':
      case 'cashMovement': {
        const movementId = data.movementId || event.entityId;
        const reference = data.reference || 'MVT';
        const description = data.description || '';
        const amount = Number(data.amount) || 0;
        const typeIndex = Number(data.typeIndex) || 0;
        const paymentMethodIndex = Number(data.paymentMethodIndex) || 0;

        await this.db.saveCashMovementRecord({
          id: `mvt-${movementId}`,
          tenantId,
          movementId,
          reference,
          description,
          amount,
          typeIndex,
          paymentMethodIndex,
          createdAt: eventDate,
        }, client);
        break;
      }

      case 'stockMovement': {
        const productId = data.productId;
        const quantity = Number(data.quantity) || 0;
        const typeIndex = Number(data.typeIndex) || 0;
        const delta = typeIndex === 0 ? quantity : -quantity;

        if (productId) {
          await this.db.upsertStockItem(tenantId, {
            productId,
            name: '',
            stockDelta: delta,
          }, client);
        }
        break;
      }
    }
  }

  async saveCloudBackup(dto: { licenseKey?: string; filename?: string; backupBase64?: string }) {
    this.logger.log(`Sauvegarde Cloud reçue depuis la caisse Desktop pour la licence ${dto.licenseKey || 'N/A'}`);
    
    let b2Result = null;
    if (dto.backupBase64) {
      try {
        const buffer = Buffer.from(dto.backupBase64, 'base64');
        const filename = dto.filename || `backup_${dto.licenseKey || 'pos'}_${Date.now()}.nma`;
        b2Result = await this.b2Storage.uploadBackup(filename, buffer, {
          licenseKey: dto.licenseKey || 'N/A',
        });
      } catch (err: any) {
        this.logger.error(`Impossible d'enregistrer la sauvegarde sur Backblaze B2: ${err.message}`);
      }
    }

    return {
      success: true,
      message: 'Sauvegarde Cloud traitée avec succès.',
      b2Storage: b2Result,
      timestamp: new Date().toISOString(),
    };
  }
}
