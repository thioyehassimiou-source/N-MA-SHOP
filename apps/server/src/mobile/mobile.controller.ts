import { Controller, Get, Post, Param, Query, Req, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery, ApiParam, ApiResponse } from '@nestjs/swagger';
import { MobileService } from './mobile.service.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';

@ApiTags('Mobile')
@ApiBearerAuth('JWT-auth')
@Controller('api/v1/mobile')
@UseGuards(JwtAuthGuard)
export class MobileController {
  constructor(private readonly mobileService: MobileService) {}

  @Get('dashboard')
  @ApiOperation({
    summary: '1. Cockpit Dashboard du Patron',
    description: 'Renvoie la synthèse complète : CA du jour, marge brute estimée, espèces vs Mobile Money, créances et alertes.',
  })
  @ApiResponse({ status: 200, description: 'Synthèse du dashboard calculée.' })
  async getDashboard(@Req() req: any) {
    return this.mobileService.getDashboard(req.tenantId);
  }

  @Get('sales')
  @ApiOperation({
    summary: '2. Suivi des Ventes & Panier Moyen',
    description: 'Consulte l\'activité commerciale filtrée par période temporelle avec répartition par mode de paiement.',
  })
  @ApiQuery({ name: 'period', required: false, enum: ['today', '7d', '30d'], description: 'Période d\'analyse' })
  async getSales(@Req() req: any, @Query('period') period?: string) {
    return this.mobileService.getSales(req.tenantId, period || 'today');
  }

  @Get('treasury')
  @ApiOperation({
    summary: '3. Contrôle de Caisse & Trésorerie',
    description: 'Calcule le solde théorique en espèces présent en boutique, le Mobile Money encaissé et détaille les dépenses.',
  })
  async getTreasury(@Req() req: any) {
    return this.mobileService.getTreasury(req.tenantId);
  }

  @Get('stock')
  @ApiOperation({
    summary: '4. Suivi des Stocks & Valorisation',
    description: 'Affiche la valeur marchande totale du stock, les ruptures totales (quantité <= 0) et les produits sous seuil bas.',
  })
  async getStock(@Req() req: any) {
    return this.mobileService.getStock(req.tenantId);
  }

  @Get('receivables')
  @ApiOperation({
    summary: '5. Créances & Crédits Clients',
    description: 'Répertorie le montant total des créances non soldées et la liste ordonnée des clients débiteurs.',
  })
  async getReceivables(@Req() req: any) {
    return this.mobileService.getReceivables(req.tenantId);
  }

  @Get('alerts')
  @ApiOperation({
    summary: '6. Centre de Notifications & Alertes',
    description: 'Liste les alertes commerciales et de gestion (stocks bas, grosses dépenses, règlements de dettes).',
  })
  async getAlerts(@Req() req: any) {
    return this.mobileService.getAlerts(req.tenantId);
  }

  @Post('alerts/:id/ack')
  @ApiOperation({
    summary: '7. Acquitter une alerte',
    description: 'Marque l\'alerte spécifiée comme lue par le commerçant.',
  })
  @ApiParam({ name: 'id', description: 'Identifiant de l\'alerte' })
  async ackAlert(@Req() req: any, @Param('id') id: string) {
    return this.mobileService.ackAlert(req.tenantId, id);
  }

  @Get('profile')
  @ApiOperation({
    summary: '8. Informations sur la boutique',
    description: 'Renvoie le nom de la boutique, la clé de licence active, la devise et l\'état de validité.',
  })
  async getProfile(@Req() req: any) {
    return this.mobileService.getProfile(req.tenantId);
  }
}
