import { DatabaseService } from '../database/database.service.js';
import { B2StorageService } from './b2-storage.service.js';
import { SyncBatchDto } from './sync.dto.js';
export declare class SyncService {
    private readonly db;
    private readonly b2Storage;
    private readonly logger;
    constructor(db: DatabaseService, b2Storage: B2StorageService);
    processBatch(dto: SyncBatchDto): Promise<{
        success: boolean;
        processedCount: number;
        skippedCount: number;
        serverTime: string;
    }>;
    private handleEvent;
    saveCloudBackup(dto: {
        licenseKey?: string;
        filename?: string;
        backupBase64?: string;
    }): Promise<{
        success: boolean;
        message: string;
        b2Storage: {
            success: boolean;
            fileId: string;
            fileName: string;
            fileUrl: string;
            sizeBytes: number;
            sha1: string;
            uploadedAt: string;
        } | null;
        timestamp: string;
    }>;
}
