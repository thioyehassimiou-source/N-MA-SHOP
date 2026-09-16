import { DatabaseService } from '../database/database.service.js';
import { SyncBatchDto } from './sync.dto.js';
export declare class SyncService {
    private readonly db;
    private readonly logger;
    constructor(db: DatabaseService);
    processBatch(dto: SyncBatchDto): Promise<{
        success: boolean;
        processedCount: number;
        skippedCount: number;
        serverTime: string;
    }>;
    private handleEvent;
}
