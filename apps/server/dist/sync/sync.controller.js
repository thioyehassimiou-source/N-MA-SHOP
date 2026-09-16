var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
import { Controller, Post, Get, Body, HttpCode, HttpStatus, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { SyncService } from './sync.service.js';
import { SyncBatchDto } from './sync.dto.js';
import { CaisseAuthGuard } from './caisse-auth.guard.js';
let SyncController = class SyncController {
    syncService;
    constructor(syncService) {
        this.syncService = syncService;
    }
    async push(dto) {
        return this.syncService.processBatch(dto);
    }
    async getStatus() {
        return {
            status: 'online',
            serverTime: new Date().toISOString(),
        };
    }
};
__decorate([
    Post('push'),
    UseGuards(CaisseAuthGuard),
    HttpCode(HttpStatus.OK),
    ApiOperation({
        summary: 'Pousser un lot d\'événements depuis la caisse Desktop',
        description: 'Ingère un lot de ventes, dépenses, mouvements de caisse et de stocks. Garantit une idempotence stricte via l\'identifiant eventId.',
    }),
    ApiResponse({ status: 200, description: 'Lot ingéré avec succès (retourne le nombre d\'événements traités et ignorés).' }),
    __param(0, Body()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [SyncBatchDto]),
    __metadata("design:returntype", Promise)
], SyncController.prototype, "push", null);
__decorate([
    Get('status'),
    ApiOperation({
        summary: 'Contrôler la connectivité du service de synchronisation',
        description: 'Vérifie que l\'API cloud est joignable et renvoie l\'heure exacte du serveur.',
    }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], SyncController.prototype, "getStatus", null);
SyncController = __decorate([
    ApiTags('Sync'),
    Controller('api/v1/sync'),
    __metadata("design:paramtypes", [SyncService])
], SyncController);
export { SyncController };
//# sourceMappingURL=sync.controller.js.map