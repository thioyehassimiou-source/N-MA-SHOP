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
import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service.js';
import { PairInitDto, PairClaimDto, LoginDto, RefreshTokenDto } from './auth.dto.js';
let AuthController = class AuthController {
    authService;
    constructor(authService) {
        this.authService = authService;
    }
    async initPairing(dto) {
        return this.authService.initPairing(dto);
    }
    async claimPairing(dto) {
        return this.authService.claimPairing(dto);
    }
    async pairDevice(dto) {
        return this.authService.claimPairing(dto);
    }
    async login(dto) {
        return this.authService.login(dto);
    }
    async refresh(dto) {
        return this.authService.refreshToken(dto);
    }
};
__decorate([
    Post('pair/init'),
    HttpCode(HttpStatus.OK),
    ApiOperation({
        summary: '1. Initialiser le jumelage (Appelé par Desktop)',
        description: 'Enregistre un jeton éphémère (10 minutes) associé à la licence de la boutique pour générer le QR Code.',
    }),
    ApiResponse({ status: 200, description: 'Jeton de jumelage initialisé avec succès.' }),
    __param(0, Body()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [PairInitDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "initPairing", null);
__decorate([
    Post('pair/claim'),
    HttpCode(HttpStatus.OK),
    ApiOperation({
        summary: '2. Réclamer le jumelage avec code PIN (Appelé par Mobile après scan)',
        description: 'Vérifie le jeton QR code, hache le code PIN secret avec bcrypt et émet la première paire de tokens JWT.',
    }),
    ApiResponse({ status: 200, description: 'Appareil jumelé avec succès, jetons d\'accès retournés.' }),
    __param(0, Body()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [PairClaimDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "claimPairing", null);
__decorate([
    Post('pair-device'),
    HttpCode(HttpStatus.OK),
    ApiOperation({
        summary: 'Alias de réclamation de jumelage',
        description: 'Endpoint alternatif compatible avec la spécification originale.',
    }),
    __param(0, Body()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [PairClaimDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "pairDevice", null);
__decorate([
    Post('login'),
    HttpCode(HttpStatus.OK),
    ApiOperation({
        summary: '3. Connexion rapide du patron via code PIN',
        description: 'Vérifie le code PIN secret à 4 chiffres sur un appareil déjà jumelé.',
    }),
    ApiResponse({ status: 200, description: 'Authentification réussie, nouveaux jetons JWT retournés.' }),
    __param(0, Body()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [LoginDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "login", null);
__decorate([
    Post('refresh'),
    HttpCode(HttpStatus.OK),
    ApiOperation({
        summary: '4. Renouveler le jeton d\'accès (Access Token)',
        description: 'Échange un Refresh Token valide contre un nouvel Access Token sans redemander le code PIN.',
    }),
    ApiResponse({ status: 200, description: 'Jeton renouvelé.' }),
    __param(0, Body()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [RefreshTokenDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "refresh", null);
AuthController = __decorate([
    ApiTags('Auth'),
    Controller('api/v1/auth'),
    __metadata("design:paramtypes", [AuthService])
], AuthController);
export { AuthController };
//# sourceMappingURL=auth.controller.js.map