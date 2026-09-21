import { Injectable, Logger } from '@nestjs/common';
import crypto from 'crypto';

@Injectable()
export class B2StorageService {
  private readonly logger = new Logger(B2StorageService.name);

  private keyId = process.env.B2_KEY_ID || '';
  private appKey = process.env.B2_APPLICATION_KEY || '';
  private bucketId = process.env.B2_BUCKET_ID || '';

  /**
   * Autorise l'accès auprès des serveurs Backblaze B2 REST API.
   */
  private async authorizeAccount() {
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

    return await res.json() as {
      apiUrl: string;
      authorizationToken: string;
      downloadUrl: string;
      s3ApiUrl: string;
    };
  }

  /**
   * Obtient une URL d'upload temporaire pour le Bucket sélectionné.
   */
  private async getUploadUrl(apiUrl: string, authToken: string) {
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

    return await res.json() as {
      uploadUrl: string;
      authorizationToken: string;
    };
  }

  /**
   * Téléverse une archive .nma (ou tout fichier) directement sur le bucket Backblaze B2.
   */
  async uploadBackup(filename: string, fileBuffer: Buffer, metadata: Record<string, string> = {}) {
    try {
      const auth = await this.authorizeAccount();
      const uploadInfo = await this.getUploadUrl(auth.apiUrl, auth.authorizationToken);

      const sha1 = crypto.createHash('sha1').update(fileBuffer).digest('hex');
      const cleanFileName = filename.replace(/[^a-zA-Z0-9_\.\-]/g, '_');
      const b2FileName = `backups/${cleanFileName}`;

      const headers: Record<string, string> = {
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

      const result = await uploadRes.json() as {
        fileId: string;
        fileName: string;
        contentLength: number;
        contentSha1: string;
      };

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
    } catch (err: any) {
      this.logger.error(`Échec du stockage Backblaze B2 : ${err.message}`);
      throw err;
    }
  }
}
