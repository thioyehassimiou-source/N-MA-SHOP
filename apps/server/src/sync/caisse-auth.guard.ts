import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import crypto from 'crypto';
import { DatabaseService } from '../database/database.service.js';

@Injectable()
export class CaisseAuthGuard implements CanActivate {
  constructor(private readonly db: DatabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const headers = request.headers;

    const licenseKey = headers['x-license-key'] || request.body?.licenseKey;
    const machineId = headers['x-machine-id'] || request.body?.machineId;
    const timestamp = headers['x-timestamp'] || request.body?.sentAt;
    const signature = headers['x-signature'];

    if (!licenseKey || !machineId) {
      throw new UnauthorizedException('Identifiants de caisse manquants (X-License-Key, X-Machine-Id).');
    }

    // 1. Contrôle anti-rejeu : tolérance maximale de 5 minutes
    if (timestamp) {
      const reqTime = new Date(timestamp).getTime();
      if (!isNaN(reqTime)) {
        const diffMs = Math.abs(Date.now() - reqTime);
        if (diffMs > 5 * 60 * 1000) {
          throw new UnauthorizedException('Horodatage expiré ou dérive d\'horloge excessive (> 5 minutes).');
        }
      }
    }

    // 2. Recherche de la boutique
    let shop = await this.db.findShopByLicense(licenseKey);
    if (!shop) {
      throw new UnauthorizedException('Boutique non reconnue pour cette clé de licence.');
    }

    // 3. Vérification de la signature cryptographique (OBLIGATOIRE)
    if (!shop.caisseSecret) {
      throw new UnauthorizedException('La boutique n\'a pas de secret de caisse configuré. Impossible d\'authentifier la caisse.');
    }
    
    if (!signature) {
      throw new UnauthorizedException('En-tête X-Signature manquant pour cette caisse enregistrée.');
    }
    const bodyString = (request as any).rawBody ? (request as any).rawBody.toString('utf-8') : JSON.stringify(request.body);
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

    // 4. Injection dans le contexte de requête
    request.shop = shop;
    request.tenantId = shop.id;
    return true;
  }
}
