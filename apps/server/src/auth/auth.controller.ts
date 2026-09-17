import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service.js';
import { PairInitDto, PairClaimDto, LoginDto, RefreshTokenDto, RegisterShopDto } from './auth.dto.js';

@ApiTags('Auth')
@Controller('api/v1/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Inscription autonome d\'une boutique mobile',
    description: 'Crée une boutique (ShopRecord) et enregistre l\'appareil mobile (DeviceRecord) en une seule transaction atomique.',
  })
  @ApiResponse({ status: 201, description: 'Boutique et appareil créés avec succès, jetons JWT retournés.' })
  @ApiResponse({ status: 400, description: 'Données invalides ou deviceId déjà enregistré.' })
  async register(@Body() dto: RegisterShopDto) {
    return this.authService.register(dto);
  }

  @Post('pair/init')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: '1. Initialiser le jumelage (Appelé par Desktop)',
    description: 'Enregistre un jeton éphémère (10 minutes) associé à la licence de la boutique pour générer le QR Code.',
  })
  @ApiResponse({ status: 200, description: 'Jeton de jumelage initialisé avec succès.' })
  async initPairing(@Body() dto: PairInitDto) {
    return this.authService.initPairing(dto);
  }

  @Post('pair/claim')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: '2. Réclamer le jumelage avec code PIN (Appelé par Mobile après scan)',
    description: 'Vérifie le jeton QR code, hache le code PIN secret avec bcrypt et émet la première paire de tokens JWT.',
  })
  @ApiResponse({ status: 200, description: 'Appareil jumelé avec succès, jetons d\'accès retournés.' })
  async claimPairing(@Body() dto: PairClaimDto) {
    return this.authService.claimPairing(dto);
  }

  @Post('pair-device')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Alias de réclamation de jumelage',
    description: 'Endpoint alternatif compatible avec la spécification originale.',
  })
  async pairDevice(@Body() dto: PairClaimDto) {
    return this.authService.claimPairing(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: '3. Connexion rapide du patron via code PIN',
    description: 'Vérifie le code PIN secret à 4 chiffres sur un appareil déjà jumelé.',
  })
  @ApiResponse({ status: 200, description: 'Authentification réussie, nouveaux jetons JWT retournés.' })
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: '4. Renouveler le jeton d\'accès (Access Token)',
    description: 'Échange un Refresh Token valide contre un nouvel Access Token sans redemander le code PIN.',
  })
  @ApiResponse({ status: 200, description: 'Jeton renouvelé.' })
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshToken(dto);
  }
}
