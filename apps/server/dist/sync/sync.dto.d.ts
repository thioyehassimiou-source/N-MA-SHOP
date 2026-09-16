export declare class SyncEventItemDto {
    eventId: string;
    entityType: string;
    entityId: string;
    action: string;
    timestamp: string;
    sequenceNumber?: number;
    schemaVersion?: number;
    data: Record<string, any>;
}
export declare class SyncBatchDto {
    machineId: string;
    licenseKey: string;
    sentAt: string;
    events: SyncEventItemDto[];
}
