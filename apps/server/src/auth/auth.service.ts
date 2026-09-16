import { Injectable, UnauthorizedException, BadRequestException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { DatabaseService } from '../database/database.service.js';
import { PairInitDto, PairClaimDto, LoginDto, RefreshTokenDto } from './auth.dto.js';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly jwtService: JwtService,
  ) {}

  async initPairing(dto: PairInitDto) {
    const shop = await this.db.upsertShop(dto.licenseKey, dto.shopName, dto.currency || 'GNF');
    const expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : new Date(Date.now() + 10 * 60 * 1000);

    const caisseSecret = shop.caisseSecret || crypto.randomBytes(32).toString('hex');
    await this.db.saveCaisseSecret(shop.id, caisseSecret);

    await this.db.savePairingToken(dto.token, shop.id, shop.businessName, shop.currency, expiresAt);
    this.logger.log(`Jeton de jumelage initialisé pour la boutique "${shop.businessName}" (${dto.token.slice(0, 8)}...)`);

    return {
      success: true,
      shopId: shop.id,
      token: dto.token,
      caisseSecret,
      expiresAt: expiresAt.toISOString(),
    };
  }

  async claimPairing(dto: PairClaimDto) {
    const pairing = await this.db.getPairingToken(dto.token);

    if (!pairing) {
      throw new BadRequestException('Code QR de jumelage introuvable ou invalide. Veuillez rescanner le code affiché sur la caisse.');
    }
    if (new Date() > new Date(pairing.expiresAt)) {
      throw new BadRequestException('Ce code QR a expiré (durée max 10 min). Veuillez régénérer un code sur la caisse.');
    }
    if (pairing.consumed) {
      throw new BadRequestException('Ce code QR a déjà été utilisé pour jumeler un appareil.');
    }
    await this.db.consumePairingToken(dto.token);

    const pinHash = await bcrypt.hash(dto.pin, 10);
    const initialRefreshTokenVal = crypto.randomBytes(40).toString('hex');
    const refreshTokenHash = crypto.createHash('sha256').update(initialRefreshTokenVal).digest('hex');

    const device = await this.db.saveDevice({
      tenantId: pairing.tenantId,
      deviceId: dto.deviceId,
      deviceName: dto.deviceName,
      pinHash,
      refreshTokenHash,
    });

    const payload = {
      sub: device.id,
      deviceId: device.deviceId,
      tenantId: device.tenantId,
      shopName: pairing.shopName,
      role: 'owner',
    };

    const accessToken = this.jwtService.sign(payload, { expiresIn: '15m' });
    const refreshToken = this.jwtService.sign({ ...payload, type: 'refresh', tokenVal: initialRefreshTokenVal }, { expiresIn: '90d' });

    this.logger.log(`Appareil "${dto.deviceName}" (${dto.deviceId}) jumelé avec succès à "${pairing.shopName}"`);

    return {
      success: true,
      accessToken,
      refreshToken,
      shop: {
        id: pairing.tenantId,
        name: pairing.shopName,
        currency: pairing.currency,
      },
    };
  }

  async login(dto: LoginDto) {
    const device = await this.db.findDevice(dto.deviceId);
    if (!device) {
      throw new UnauthorizedException('Appareil non reconnu. Veuillez scanner le QR Code sur la caisse pour le jumeler.');
    }
    if (device.isRevoked) {
      throw new UnauthorizedException('Cet appareil a été révoqué par le propriétaire.');
    }

    if (device.lockoutUntil && new Date() < new Date(device.lockoutUntil)) {
      const remainingSec = Math.ceil((new Date(device.lockoutUntil).getTime() - Date.now()) / 1000);
      throw new UnauthorizedException(`Appareil temporairement verrouillé suite à 5 tentatives infructueuses. Réessayez dans ${remainingSec} secondes.`);
    }

    const isMatch = await bcrypt.compare(dto.pin, device.pinHash);
    if (!isMatch) {
      const failed = (device.failedPinAttempts || 0) + 1;
      if (failed >= 5) {
        const lockout = new Date(Date.now() + 5 * 60 * 1000);
        await this.db.updateDeviceFailedPin(device.deviceId, 0, lockout);
        throw new UnauthorizedException('Code PIN incorrect. 5 tentatives infructueuses : appareil verrouillé 5 minutes.');
      } else {
        await this.db.updateDeviceFailedPin(device.deviceId, failed, null);
        throw new UnauthorizedException(`Code PIN incorrect (${failed}/5 tentatives avant verrouillage).`);
      }
    }

    await this.db.resetDeviceLockout(device.deviceId);
    await this.db.updateDeviceLastSeen(device.deviceId);
    const shop = await this.db.findShopById(device.tenantId);

    const payload = {
      sub: device.id,
      deviceId: device.deviceId,
      tenantId: device.tenantId,
      shopName: shop?.businessName || 'Boutique',
      role: 'owner',
    };

    const newRefreshTokenVal = crypto.randomBytes(40).toString('hex');
    const newRefreshHash = crypto.createHash('sha256').update(newRefreshTokenVal).digest('hex');
    await this.db.updateDeviceRefreshToken(device.deviceId, newRefreshHash);

    const accessToken = this.jwtService.sign(payload, { expiresIn: '15m' });
    const refreshToken = this.jwtService.sign({ ...payload, type: 'refresh', tokenVal: newRefreshTokenVal }, { expiresIn: '90d' });

    return {
      success: true,
      accessToken,
      refreshToken,
      shop: {
        id: device.tenantId,
        name: shop?.businessName || 'Boutique',
        currency: shop?.currency || 'GNF',
      },
    };
  }

  async refreshToken(dto: RefreshTokenDto | string) {
    try {
      const tokenStr = typeof dto === 'string' ? dto : dto?.refreshToken;
      const decoded = this.jwtService.verify(tokenStr) as any;
      if (decoded.type !== 'refresh' || !decoded.deviceId) {
        throw new UnauthorizedException('Format de jeton de rafraîchissement invalide.');
      }

      const device = await this.db.findDevice(decoded.deviceId);
      if (!device || device.isRevoked) {
        throw new UnauthorizedException('Appareil révoqué ou introuvable.');
      }

      const tokenVal = decoded.tokenVal || '';
      const computedHash = crypto.createHash('sha256').update(tokenVal).digest('hex');
      if (device.refreshTokenHash && device.refreshTokenHash !== computedHash) {
        throw new UnauthorizedException('Jeton de rafraîchissement déjà utilisé ou révoqué.');
      }

      const payload = {
        sub: device.id,
        deviceId: device.deviceId,
        tenantId: device.tenantId,
        shopName: decoded.shopName,
        role: 'owner',
      };

      const newRefreshTokenVal = crypto.randomBytes(40).toString('hex');
      const newRefreshHash = crypto.createHash('sha256').update(newRefreshTokenVal).digest('hex');
      await this.db.updateDeviceRefreshToken(device.deviceId, newRefreshHash);

      const accessToken = this.jwtService.sign(payload, { expiresIn: '15m' });
      const newRefreshToken = this.jwtService.sign({ ...payload, type: 'refresh', tokenVal: newRefreshTokenVal }, { expiresIn: '90d' });

      return { success: true, accessToken, refreshToken: newRefreshToken };
    } catch (err: any) {
      if (err instanceof UnauthorizedException) throw err;
      throw new UnauthorizedException('Session expirée, veuillez saisir à nouveau votre code PIN.');
    }
  }
}
