import { SyncService } from './sync.service.js';
import { SyncBatchDto } from './sync.dto.js';
export declare class SyncController {
    private readonly syncService;
    constructor(syncService: SyncService);
    push(dto: SyncBatchDto): Promise<{
        success: boolean;
        processedCount: number;
        skippedCount: number;
        serverTime: string;
    }>;
    getStatus(): Promise<{
        status: string;
        serverTime: string;
    }>;
    uploadBackup(body: any): Promise<{
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
    getLatestBackup(body: any): Promise<{
        success: boolean;
        backup: {
            fileId: string;
            fileName: string;
            sizeBytes: number;
            uploadedAt: string;
        };
        error?: undefined;
    } | {
        success: boolean;
        error: any;
        backup?: undefined;
    }>;
    downloadBackup(body: any): Promise<{
        success: boolean;
        fileName: string;
        sizeBytes: number;
        backupBase64: string;
        downloadedAt: string;
    }>;
}
