var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
import { ApiProperty } from '@nestjs/swagger';
import { Allow, IsArray, IsNotEmpty, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
export class SyncEventItemDto {
    eventId;
    entityType;
    entityId;
    action;
    timestamp;
    sequenceNumber;
    schemaVersion;
    data;
}
__decorate([
    ApiProperty({ example: 'evt-uuid-1234', description: 'Identifiant UUID unique de l\'événement (clé d\'idempotence)' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncEventItemDto.prototype, "eventId", void 0);
__decorate([
    ApiProperty({ example: 'sale', enum: ['sale', 'creditPayment', 'expense', 'cashMovement', 'stockMovement'], description: 'Type de l\'entité synchronisée' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncEventItemDto.prototype, "entityType", void 0);
__decorate([
    ApiProperty({ example: 'sale-001', description: 'Identifiant de l\'entité métier dans la base SQLite locale' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncEventItemDto.prototype, "entityId", void 0);
__decorate([
    ApiProperty({ example: 'create', enum: ['create', 'update', 'delete'], description: 'Action effectuée' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncEventItemDto.prototype, "action", void 0);
__decorate([
    ApiProperty({ example: '2026-09-14T12:30:00Z', description: 'Horodatage ISO de la création locale' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncEventItemDto.prototype, "timestamp", void 0);
__decorate([
    ApiProperty({ example: 1042, required: false, description: 'Séquence monotone par machine' }),
    Allow(),
    __metadata("design:type", Number)
], SyncEventItemDto.prototype, "sequenceNumber", void 0);
__decorate([
    ApiProperty({ example: 1, required: false, description: 'Version du schéma du payload' }),
    Allow(),
    __metadata("design:type", Number)
], SyncEventItemDto.prototype, "schemaVersion", void 0);
__decorate([
    ApiProperty({
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
    }),
    Allow(),
    __metadata("design:type", Object)
], SyncEventItemDto.prototype, "data", void 0);
export class SyncBatchDto {
    machineId;
    licenseKey;
    sentAt;
    events;
}
__decorate([
    ApiProperty({ example: 'DESKTOP-HWID-ABC', description: 'Identifiant matériel du PC caisse émetteur' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncBatchDto.prototype, "machineId", void 0);
__decorate([
    ApiProperty({ example: 'TEST-LICENSE-KEY', description: 'Clé de licence de la boutique' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncBatchDto.prototype, "licenseKey", void 0);
__decorate([
    ApiProperty({ example: '2026-09-14T12:30:05Z', description: 'Horodatage d\'émission du batch' }),
    IsString(),
    IsNotEmpty(),
    __metadata("design:type", String)
], SyncBatchDto.prototype, "sentAt", void 0);
__decorate([
    ApiProperty({ type: [SyncEventItemDto], description: 'Liste des deltas/événements transactionnels à synchroniser' }),
    IsArray(),
    ValidateNested({ each: true }),
    Type(() => SyncEventItemDto),
    __metadata("design:type", Array)
], SyncBatchDto.prototype, "events", void 0);
//# sourceMappingURL=sync.dto.js.map