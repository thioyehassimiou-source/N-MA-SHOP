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

  @Post('backup/upload')
  @UseGuards(CaisseAuthGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Sauvegarder l\'archive complète (.nma) de la caisse dans le Cloud',
    description: 'Permet à l\'application Desktop de sauvegarder un instantané chiffré et sécurisé dans le Cloud.',
  })
  @ApiResponse({ status: 200, description: 'Sauvegarde Cloud enregistrée avec succès.' })
  async uploadBackup(@Body() body: any) {
    return this.syncService.saveCloudBackup(body);
  }

  @Post('backup/latest')
  @UseGuards(CaisseAuthGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Consulter les métadonnées de la dernière sauvegarde Cloud de la caisse',
    description: 'Permet à la caisse de savoir si une sauvegarde existe dans Backblaze B2 et sa taille/date.',
  })
  @ApiResponse({ status: 200, description: 'Informations sur la dernière sauvegarde.' })
  async getLatestBackup(@Body() body: any) {
    return this.syncService.getLatestCloudBackup(body.licenseKey);
  }

  @Post('backup/download')
  @UseGuards(CaisseAuthGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Télécharger la dernière sauvegarde Cloud (.nma) de la caisse',
    description: 'Permet à l\'application Desktop de restaurer son état complet depuis Backblaze B2.',
  })
  @ApiResponse({ status: 200, description: 'Archive .nma retournée encodée en base64 pour restauration.' })
  async downloadBackup(@Body() body: any) {
    const licenseKey = body.licenseKey;
    const result = await this.syncService.downloadLatestCloudBackup(licenseKey);
    return {
      success: true,
      fileName: result.fileName,
      sizeBytes: result.buffer.length,
      backupBase64: result.buffer.toString('base64'),
      downloadedAt: new Date().toISOString(),
    };
  }
}

