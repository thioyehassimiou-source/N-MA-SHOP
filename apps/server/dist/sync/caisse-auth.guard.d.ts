import { CanActivate, ExecutionContext } from '@nestjs/common';
import { DatabaseService } from '../database/database.service.js';
export declare class CaisseAuthGuard implements CanActivate {
    private readonly db;
    constructor(db: DatabaseService);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
