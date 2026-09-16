import { Module } from '@nestjs/common';
import { MobileController } from './mobile.controller.js';
import { MobileService } from './mobile.service.js';
import { AuthModule } from '../auth/auth.module.js';

@Module({
  imports: [AuthModule],
  controllers: [MobileController],
  providers: [MobileService],
  exports: [MobileService],
})
export class MobileModule {}
