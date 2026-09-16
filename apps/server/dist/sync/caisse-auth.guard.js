var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { Injectable, UnauthorizedException } from '@nestjs/common';
import crypto from 'crypto';
import { DatabaseService } from '../database/database.service.js';
let CaisseAuthGuard = class CaisseAuthGuard {
    db;
    constructor(db) {
        this.db = db;
    }
    async canActivate(context) {
        const request = context.switchToHttp().getRequest();
        const headers = request.headers;
        const licenseKey = headers['x-license-key'] || request.body?.licenseKey;
        const machineId = headers['x-machine-id'] || request.body?.machineId;
        const timestamp = headers['x-timestamp'] || request.body?.sentAt;
        const signature = headers['x-signature'];
        if (!licenseKey || !machineId) {
            throw new UnauthorizedException('Identifiants de caisse manquants (X-License-Key, X-Machine-Id).');
        }
        if (timestamp) {
            const reqTime = new Date(timestamp).getTime();
            if (!isNaN(reqTime)) {
                const diffMs = Math.abs(Date.now() - reqTime);
                if (diffMs > 5 * 60 * 1000) {
                    throw new UnauthorizedException('Horodatage expiré ou dérive d\'horloge excessive (> 5 minutes).');
                }
            }
        }
        let shop = await this.db.findShopByLicense(licenseKey);
        if (!shop) {
            throw new UnauthorizedException('Boutique non reconnue pour cette clé de licence.');
        }
        if (!shop.caisseSecret) {
            throw new UnauthorizedException('La boutique n\'a pas de secret de caisse configuré. Impossible d\'authentifier la caisse.');
        }
        if (!signature) {
            throw new UnauthorizedException('En-tête X-Signature manquant pour cette caisse enregistrée.');
        }
        const bodyString = request.rawBody ? request.rawBody.toString('utf-8') : JSON.stringify(request.body);
        const rawPayload = `${timestamp}.${bodyString}`;
        const expectedSignature = crypto
            .createHmac('sha256', shop.caisseSecret)
            .update(rawPayload)
            .digest('hex');
        const sigBuf = Buffer.from(signature);
        const expBuf = Buffer.from(expectedSignature);
        if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
            throw new UnauthorizedException('Signature HMAC-SHA256 de la caisse invalide.');
        }
        request.shop = shop;
        request.tenantId = shop.id;
        return true;
    }
};
CaisseAuthGuard = __decorate([
    Injectable(),
    __metadata("design:paramtypes", [DatabaseService])
], CaisseAuthGuard);
export { CaisseAuthGuard };
//# sourceMappingURL=caisse-auth.guard.js.map