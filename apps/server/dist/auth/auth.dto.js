var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';
export class PairInitDto {
    token;
    machineId;
    licenseKey;
    shopName;
    currency;
    expiresAt;
}
__decorate([
    ApiProperty({ example: 'pair-uuid-123456', description: 'Jeton UUID unique généré par le Desktop' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], PairInitDto.prototype, "token", void 0);
__decorate([
    ApiProperty({ example: 'DESKTOP-HWID-ABC', description: 'Identifiant matériel unique du PC caisse' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], PairInitDto.prototype, "machineId", void 0);
__decorate([
    ApiProperty({ example: 'TEST-LICENSE-KEY', description: 'Clé de licence active de la boutique' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], PairInitDto.prototype, "licenseKey", void 0);
__decorate([
    ApiProperty({ example: 'Boutique Diallo & Frères', description: 'Nom commercial de la boutique' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], PairInitDto.prototype, "shopName", void 0);
__decorate([
    ApiPropertyOptional({ example: 'GNF', default: 'GNF', description: 'Devise de la boutique' }),
    IsString(),
    IsOptional(),
    __metadata("design:type", String)
], PairInitDto.prototype, "currency", void 0);
__decorate([
    ApiPropertyOptional({ example: '2026-09-14T12:45:00Z', description: 'Date d\'expiration (10 minutes max)' }),
    IsString(),
    IsOptional(),
    __metadata("design:type", String)
], PairInitDto.prototype, "expiresAt", void 0);
export class PairClaimDto {
    token;
    deviceId;
    deviceName;
    pin;
    machineId;
}
__decorate([
    ApiProperty({ example: 'pair-uuid-123456', description: 'Jeton de jumelage scanné depuis le QR Code' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], PairClaimDto.prototype, "token", void 0);
__decorate([
    ApiProperty({ example: 'SMARTPHONE-DEVICE-001', description: 'Identifiant unique de l\'appareil mobile' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], PairClaimDto.prototype, "deviceId", void 0);
__decorate([
    ApiProperty({ example: 'Samsung Galaxy S23 Patron', description: 'Nom de l\'appareil du commerçant' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], PairClaimDto.prototype, "deviceName", void 0);
__decorate([
    ApiProperty({ example: '1234', description: 'Code PIN secret défini par le patron (4 à 8 chiffres)' }),
    IsString(),
    IsNotEmpty(),
    Length(4, 8),
    __metadata("design:type", String)
], PairClaimDto.prototype, "pin", void 0);
__decorate([
    ApiPropertyOptional({ example: 'DESKTOP-HWID-ABC', description: 'Identifiant machine facultatif' }),
    IsString(),
    IsOptional(),
    __metadata("design:type", String)
], PairClaimDto.prototype, "machineId", void 0);
export class LoginDto {
    deviceId;
    pin;
}
__decorate([
    ApiProperty({ example: 'SMARTPHONE-DEVICE-001', description: 'Identifiant unique de l\'appareil mobile' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], LoginDto.prototype, "deviceId", void 0);
__decorate([
    ApiProperty({ example: '1234', description: 'Code PIN secret' }),
    IsString(),
    IsNotEmpty(),
    Length(4, 8),
    __metadata("design:type", String)
], LoginDto.prototype, "pin", void 0);
export class RefreshTokenDto {
    refreshToken;
}
__decorate([
    ApiProperty({ example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...', description: 'Refresh Token JWT valide' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], RefreshTokenDto.prototype, "refreshToken", void 0);
//# sourceMappingURL=auth.dto.js.map