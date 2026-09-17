import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';

export class PairInitDto {
  @ApiProperty({ example: 'pair-uuid-123456', description: 'Jeton UUID unique généré par le Desktop' })
  @IsString()
  @IsNotEmpty()
  token: string;

  @ApiProperty({ example: 'DESKTOP-HWID-ABC', description: 'Identifiant matériel unique du PC caisse' })
  @IsString()
  @IsNotEmpty()
  machineId: string;

  @ApiProperty({ example: 'TEST-LICENSE-KEY', description: 'Clé de licence active de la boutique' })
  @IsString()
  @IsNotEmpty()
  licenseKey: string;

  @ApiProperty({ example: 'Boutique Diallo & Frères', description: 'Nom commercial de la boutique' })
  @IsString()
  @IsNotEmpty()
  shopName: string;

  @ApiPropertyOptional({ example: 'GNF', default: 'GNF', description: 'Devise de la boutique' })
  @IsString()
  @IsOptional()
  currency?: string;

  @ApiPropertyOptional({ example: '2026-09-14T12:45:00Z', description: 'Date d\'expiration (10 minutes max)' })
  @IsString()
  @IsOptional()
  expiresAt?: string;
}

export class PairClaimDto {
  @ApiProperty({ example: 'pair-uuid-123456', description: 'Jeton de jumelage scanné depuis le QR Code' })
  @IsString()
  @IsNotEmpty()
  token: string;

  @ApiProperty({ example: 'SMARTPHONE-DEVICE-001', description: 'Identifiant unique de l\'appareil mobile' })
  @IsString()
  @IsNotEmpty()
  deviceId: string;

  @ApiProperty({ example: 'Samsung Galaxy S23 Patron', description: 'Nom de l\'appareil du commerçant' })
  @IsString()
  @IsNotEmpty()
  deviceName: string;

  @ApiProperty({ example: '1234', description: 'Code PIN secret défini par le patron (4 à 8 chiffres)' })
  @IsString()
  @IsNotEmpty()
  @Length(4, 8)
  pin: string;

  @ApiPropertyOptional({ example: 'DESKTOP-HWID-ABC', description: 'Identifiant machine facultatif' })
  @IsString()
  @IsOptional()
  machineId?: string;
}

export class LoginDto {
  @ApiProperty({ example: 'SMARTPHONE-DEVICE-001', description: 'Identifiant unique de l\'appareil mobile' })
  @IsString()
  @IsNotEmpty()
  deviceId: string;

  @ApiProperty({ example: '1234', description: 'Code PIN secret' })
  @IsString()
  @IsNotEmpty()
  @Length(4, 8)
  pin: string;
}

export class RefreshTokenDto {
  @ApiProperty({ example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...', description: 'Refresh Token JWT valide' })
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class RegisterShopDto {
  @ApiProperty({ example: 'Boutique Diallo & Frères', description: 'Nom commercial de la boutique' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 100)
  shopName: string;

  @ApiPropertyOptional({ example: 'GNF', default: 'GNF', description: 'Devise principale de la boutique' })
  @IsString()
  @IsOptional()
  currency?: string;

  @ApiProperty({ example: '1234', description: 'Code PIN secret à 4-8 chiffres' })
  @IsString()
  @IsNotEmpty()
  @Length(4, 8)
  pin: string;

  @ApiProperty({ example: 'Smartphone Patron', description: 'Nom de l\'appareil du commerçant' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 100)
  deviceName: string;

  @ApiProperty({ example: 'mob-a1b2c3d4-5678', description: 'Identifiant unique de l\'appareil mobile' })
  @IsString()
  @IsNotEmpty()
  @Length(5, 128)
  deviceId: string;
}

