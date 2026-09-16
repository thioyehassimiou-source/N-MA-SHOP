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
import { Controller, Get, Post, Param, Query, Req, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery, ApiParam, ApiResponse } from '@nestjs/swagger';
import { MobileService } from './mobile.service.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
let MobileController = class MobileController {
    mobileService;
    constructor(mobileService) {
        this.mobileService = mobileService;
    }
    async getDashboard(req) {
        return this.mobileService.getDashboard(req.tenantId);
    }
    async getSales(req, period) {
        return this.mobileService.getSales(req.tenantId, period || 'today');
    }
    async getTreasury(req) {
        return this.mobileService.getTreasury(req.tenantId);
    }
    async getStock(req) {
        return this.mobileService.getStock(req.tenantId);
    }
    async getReceivables(req) {
        return this.mobileService.getReceivables(req.tenantId);
    }
    async getAlerts(req) {
        return this.mobileService.getAlerts(req.tenantId);
    }
    async ackAlert(req, id) {
        return this.mobileService.ackAlert(req.tenantId, id);
    }
    async getProfile(req) {
        return this.mobileService.getProfile(req.tenantId);
    }
};
__decorate([
    Get('dashboard'),
    ApiOperation({
        summary: '1. Cockpit Dashboard du Patron',
        description: 'Renvoie la synthèse complète : CA du jour, marge brute estimée, espèces vs Mobile Money, créances et alertes.',
    }),
    ApiResponse({ status: 200, description: 'Synthèse du dashboard calculée.' }),
    __param(0, Req()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "getDashboard", null);
__decorate([
    Get('sales'),
    ApiOperation({
        summary: '2. Suivi des Ventes & Panier Moyen',
        description: 'Consulte l\'activité commerciale filtrée par période temporelle avec répartition par mode de paiement.',
    }),
    ApiQuery({ name: 'period', required: false, enum: ['today', '7d', '30d'], description: 'Période d\'analyse' }),
    __param(0, Req()),
    __param(1, Query('period')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "getSales", null);
__decorate([
    Get('treasury'),
    ApiOperation({
        summary: '3. Contrôle de Caisse & Trésorerie',
        description: 'Calcule le solde théorique en espèces présent en boutique, le Mobile Money encaissé et détaille les dépenses.',
    }),
    __param(0, Req()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "getTreasury", null);
__decorate([
    Get('stock'),
    ApiOperation({
        summary: '4. Suivi des Stocks & Valorisation',
        description: 'Affiche la valeur marchande totale du stock, les ruptures totales (quantité <= 0) et les produits sous seuil bas.',
    }),
    __param(0, Req()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "getStock", null);
__decorate([
    Get('receivables'),
    ApiOperation({
        summary: '5. Créances & Crédits Clients',
        description: 'Répertorie le montant total des créances non soldées et la liste ordonnée des clients débiteurs.',
    }),
    __param(0, Req()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "getReceivables", null);
__decorate([
    Get('alerts'),
    ApiOperation({
        summary: '6. Centre de Notifications & Alertes',
        description: 'Liste les alertes commerciales et de gestion (stocks bas, grosses dépenses, règlements de dettes).',
    }),
    __param(0, Req()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "getAlerts", null);
__decorate([
    Post('alerts/:id/ack'),
    ApiOperation({
        summary: '7. Acquitter une alerte',
        description: 'Marque l\'alerte spécifiée comme lue par le commerçant.',
    }),
    ApiParam({ name: 'id', description: 'Identifiant de l\'alerte' }),
    __param(0, Req()),
    __param(1, Param('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "ackAlert", null);
__decorate([
    Get('profile'),
    ApiOperation({
        summary: '8. Informations sur la boutique',
        description: 'Renvoie le nom de la boutique, la clé de licence active, la devise et l\'état de validité.',
    }),
    __param(0, Req()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MobileController.prototype, "getProfile", null);
MobileController = __decorate([
    ApiTags('Mobile'),
    ApiBearerAuth('JWT-auth'),
    Controller('api/v1/mobile'),
    UseGuards(JwtAuthGuard),
    __metadata("design:paramtypes", [MobileService])
], MobileController);
export { MobileController };
//# sourceMappingURL=mobile.controller.js.map