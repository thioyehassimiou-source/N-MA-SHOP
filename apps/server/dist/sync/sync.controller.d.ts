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
}
