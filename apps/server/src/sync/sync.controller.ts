import { Controller, Post, Get, Body, HttpCode, HttpStatus, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { SyncService } from './sync.service.js';
import { SyncBatchDto } from './sync.dto.js';
import { CaisseAuthGuard } from './caisse-auth.guard.js';

@ApiTags('Sync')
@Controller('api/v1/sync')
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post('push')
  @UseGuards(CaisseAuthGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Pousser un lot d\'événements depuis la caisse Desktop',
    description: 'Ingère un lot de ventes, dépenses, mouvements de caisse et de stocks. Garantit une idempotence stricte via l\'identifiant eventId.',
  })
  @ApiResponse({ status: 200, description: 'Lot ingéré avec succès (retourne le nombre d\'événements traités et ignorés).' })
  async push(@Body() dto: SyncBatchDto) {
    return this.syncService.processBatch(dto);
  }

  @Get('status')
  @ApiOperation({
    summary: 'Contrôler la connectivité du service de synchronisation',
    description: 'Vérifie que l\'API cloud est joignable et renvoie l\'heure exacte du serveur.',
  })
  async getStatus() {
    return {
      status: 'online',
      serverTime: new Date().toISOString(),
    };
  }
}
