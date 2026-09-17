export declare class PairInitDto {
    token: string;
    machineId: string;
    licenseKey: string;
    shopName: string;
    currency?: string;
    expiresAt?: string;
}
export declare class PairClaimDto {
    token: string;
    deviceId: string;
    deviceName: string;
    pin: string;
    machineId?: string;
}
export declare class LoginDto {
    deviceId: string;
    pin: string;
}
export declare class RefreshTokenDto {
    refreshToken: string;
}
export declare class RegisterShopDto {
    shopName: string;
    currency?: string;
    pin: string;
    deviceName: string;
    deviceId: string;
}
