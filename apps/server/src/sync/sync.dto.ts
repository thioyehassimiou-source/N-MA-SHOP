import { ApiProperty } from '@nestjs/swagger';
import { Allow, IsArray, IsNotEmpty, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class SyncEventItemDto {
  @ApiProperty({ example: 'evt-uuid-1234', description: 'Identifiant UUID unique de l\'événement (clé d\'idempotence)' })
  @IsString()
  @IsNotEmpty()
  eventId: string;

  @ApiProperty({ example: 'sale', enum: ['sale', 'creditPayment', 'expense', 'cashMovement', 'stockMovement'], description: 'Type de l\'entité synchronisée' })
  @IsString()
  @IsNotEmpty()
  entityType: string;

  @ApiProperty({ example: 'sale-001', description: 'Identifiant de l\'entité métier dans la base SQLite locale' })
  @IsString()
  @IsNotEmpty()
  entityId: string;

  @ApiProperty({ example: 'create', enum: ['create', 'update', 'delete'], description: 'Action effectuée' })
  @IsString()
  @IsNotEmpty()
  action: string;

  @ApiProperty({ example: '2026-09-14T12:30:00Z', description: 'Horodatage ISO de la création locale' })
  @IsString()
  @IsNotEmpty()
  timestamp: string;

  @ApiProperty({ example: 1042, required: false, description: 'Séquence monotone par machine' })
  @Allow()
  sequenceNumber?: number;

  @ApiProperty({ example: 1, required: false, description: 'Version du schéma du payload' })
  @Allow()
  schemaVersion?: number;

  @ApiProperty({
    example: {
      saleId: 'sale-001',
      reference: 'FAC-2026-001',
      customerName: 'Amadou Bah',
      totalAmount: 500000,
      amountPaid: 300000,
      paymentMethodIndex: 0,
      lines: [{ productId: 'prod-riz', label: 'Sac Riz 50kg', quantity: 2, unitPrice: 250000, unitCost: 210000 }],
    },
    description: 'Données détaillées de la transaction',
  })
  @Allow()
  data: Record<string, any>;
}

export class SyncBatchDto {
  @ApiProperty({ example: 'DESKTOP-HWID-ABC', description: 'Identifiant matériel du PC caisse émetteur' })
  @IsString()
  @IsNotEmpty()
  machineId: string;

  @ApiProperty({ example: 'TEST-LICENSE-KEY', description: 'Clé de licence de la boutique' })
  @IsString()
  @IsNotEmpty()
  licenseKey: string;

  @ApiProperty({ example: '2026-09-14T12:30:05Z', description: 'Horodatage d\'émission du batch' })
  @IsString()
  @IsNotEmpty()
  sentAt: string;

  @ApiProperty({ type: [SyncEventItemDto], description: 'Liste des deltas/événements transactionnels à synchroniser' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncEventItemDto)
  events: SyncEventItemDto[];
}
