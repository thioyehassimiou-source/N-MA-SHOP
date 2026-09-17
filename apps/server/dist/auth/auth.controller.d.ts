import { AuthService } from './auth.service.js';
import { PairInitDto, PairClaimDto, LoginDto, RefreshTokenDto, RegisterShopDto } from './auth.dto.js';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
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
    pairDevice(dto: PairClaimDto): Promise<{
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
    refresh(dto: RefreshTokenDto): Promise<{
        success: boolean;
        accessToken: string;
        refreshToken: string;
    }>;
}
