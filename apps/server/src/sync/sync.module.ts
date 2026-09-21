import { Module } from '@nestjs/common';
import { SyncController } from './sync.controller.js';
import { SyncService } from './sync.service.js';
import { B2StorageService } from './b2-storage.service.js';

@Module({
  controllers: [SyncController],
  providers: [SyncService, B2StorageService],
  exports: [SyncService, B2StorageService],
})
export class SyncModule {}
