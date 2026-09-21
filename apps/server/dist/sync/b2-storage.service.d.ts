export declare class B2StorageService {
    private readonly logger;
    private keyId;
    private appKey;
    private bucketId;
    private authorizeAccount;
    private getUploadUrl;
    uploadBackup(filename: string, fileBuffer: Buffer, metadata?: Record<string, string>): Promise<{
        success: boolean;
        fileId: string;
        fileName: string;
        fileUrl: string;
        sizeBytes: number;
        sha1: string;
        uploadedAt: string;
    }>;
}
