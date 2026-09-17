import { JwtService } from '@nestjs/jwt';
import { DatabaseService } from '../database/database.service.js';
import { PairInitDto, PairClaimDto, LoginDto, RefreshTokenDto, RegisterShopDto } from './auth.dto.js';
export declare class AuthService {
    private readonly db;
    private readonly jwtService;
    private readonly logger;
    constructor(db: DatabaseService, jwtService: JwtService);
    register(dto: RegisterShopDto): Promise<{
        success: boolean;
        accessToken: string;
        refreshToken: string;
        shop: {
            id: string;
            name: string;
            currency: string;
        };
    }>;
    initPairing(dto: PairInitDto): Promise<{
        success: boolean;
        shopId: string;
        token: string;
        caisseSecret: string;
        expiresAt: string;
    }>;
    claimPairing(dto: PairClaimDto): Promise<{
        success: boolean;
        accessToken: string;
        refreshToken: string;
        shop: {
            id: any;
            name: any;
            currency: any;
        };
    }>;
    login(dto: LoginDto): Promise<{
        success: boolean;
        accessToken: string;
        refreshToken: string;
        shop: {
            id: string;
            name: string;
            currency: string;
        };
    }>;
    refreshToken(dto: RefreshTokenDto | string): Promise<{
        success: boolean;
        accessToken: string;
        refreshToken: string;
    }>;
}
