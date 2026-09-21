var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var B2StorageService_1;
import { Injectable, Logger } from '@nestjs/common';
import crypto from 'crypto';
let B2StorageService = B2StorageService_1 = class B2StorageService {
    logger = new Logger(B2StorageService_1.name);
    keyId = process.env.B2_KEY_ID || '';
    appKey = process.env.B2_APPLICATION_KEY || '';
    bucketId = process.env.B2_BUCKET_ID || '';
    async authorizeAccount() {
        this.keyId = process.env.B2_KEY_ID || '';
        this.appKey = process.env.B2_APPLICATION_KEY || '';
        this.bucketId = process.env.B2_BUCKET_ID || '';
        if (!this.keyId || !this.appKey || !this.bucketId) {
            throw new Error('Les identifiants Backblaze B2 (B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET_ID) sont absents du .env');
        }
        const authHeader = 'Basic ' + Buffer.from(`${this.keyId}:${this.appKey}`).toString('base64');
        const res = await fetch('https://api.backblazeb2.com/b2api/v2/b2_authorize_account', {
            headers: { Authorization: authHeader },
        });
        if (!res.ok) {
            const errText = await res.text();
            throw new Error(`Échec d'authentification Backblaze B2 (${res.status}): ${errText}`);
        }
        return await res.json();
    }
    async getUploadUrl(apiUrl, authToken) {
        const res = await fetch(`${apiUrl}/b2api/v2/b2_get_upload_url`, {
            method: 'POST',
            headers: {
                Authorization: authToken,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ bucketId: this.bucketId }),
        });
        if (!res.ok) {
            const errText = await res.text();
            throw new Error(`Échec d'obtention de l'URL d'upload Backblaze (${res.status}): ${errText}`);
        }
        return await res.json();
    }
    async uploadBackup(filename, fileBuffer, metadata = {}) {
        try {
            const auth = await this.authorizeAccount();
            const uploadInfo = await this.getUploadUrl(auth.apiUrl, auth.authorizationToken);
            const sha1 = crypto.createHash('sha1').update(fileBuffer).digest('hex');
            const cleanFileName = filename.replace(/[^a-zA-Z0-9_\.\-]/g, '_');
            const b2FileName = `backups/${cleanFileName}`;
            const headers = {
                Authorization: uploadInfo.authorizationToken,
                'X-Bz-File-Name': encodeURIComponent(b2FileName),
                'Content-Type': 'application/octet-stream',
                'Content-Length': fileBuffer.length.toString(),
                'X-Bz-Content-Sha1': sha1,
            };
            for (const [key, value] of Object.entries(metadata)) {
                headers[`X-Bz-Info-${key}`] = encodeURIComponent(value);
            }
            const uploadRes = await fetch(uploadInfo.uploadUrl, {
                method: 'POST',
                headers,
                body: new Uint8Array(fileBuffer),
            });
            if (!uploadRes.ok) {
                const errText = await uploadRes.text();
                throw new Error(`Erreur lors du transfert du fichier vers Backblaze B2 (${uploadRes.status}): ${errText}`);
            }
            const result = await uploadRes.json();
            const fileUrl = `${auth.downloadUrl}/file/${this.bucketId}/${result.fileName}`;
            this.logger.log(`Sauvegarde .nma téléversée sur Backblaze B2 : ${result.fileName} (${(result.contentLength / 1024).toFixed(1)} KB)`);
            return {
                success: true,
                fileId: result.fileId,
                fileName: result.fileName,
                fileUrl,
                sizeBytes: result.contentLength,
                sha1: result.contentSha1,
                uploadedAt: new Date().toISOString(),
            };
        }
        catch (err) {
            this.logger.error(`Échec du stockage Backblaze B2 : ${err.message}`);
            throw err;
        }
    }
};
B2StorageService = B2StorageService_1 = __decorate([
    Injectable()
], B2StorageService);
export { B2StorageService };
//# sourceMappingURL=b2-storage.service.js.map