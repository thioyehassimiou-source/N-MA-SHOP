import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';
async function bootstrap() {
    const app = await NestFactory.create(AppModule, { rawBody: true });
    app.enableCors({ origin: true, credentials: true });
    app.useGlobalPipes(new ValidationPipe({
        whitelist: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
    }));
    const config = new DocumentBuilder()
        .setTitle("N'MaShop Cloud API — Documentation & Tests")
        .setDescription("API Cloud multi-tenant pour l'écosystème N'MaShop Mobile (\"Le téléphone du patron\").\n\n" +
        "### Workflow de test interactif dans Swagger :\n" +
        "1. **Initialiser le jumelage** (`POST /api/v1/auth/pair/init`) : enregistre un jeton éphémère (ex: `TEST-PAIR-01`).\n" +
        "2. **Réclamer le jumelage** (`POST /api/v1/auth/pair/claim`) : associe votre appareil avec un code PIN (ex: `1234`). Copiez le `accessToken` généré !\n" +
        "3. **S'authentifier** : Cliquez sur le bouton vert **Authorize 🔓** tout en haut à droite et collez le token.\n" +
        "4. **Simuler la synchronisation caisse Desktop** (`POST /api/v1/sync/push`) : injectez des ventes, dépenses ou mouvements.\n" +
        "5. **Consulter l'application mobile** : testez les endpoints `GET /api/v1/mobile/*` (Cockpit Dashboard, Trésorerie, Stocks, Créances).")
        .setVersion('1.0')
        .addBearerAuth({
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'Authorization',
        description: 'Collez votre jeton JWT (obtenu via /auth/pair/claim ou /auth/login)',
        in: 'header',
    }, 'JWT-auth')
        .addTag('Auth', 'Jumelage et authentification par code PIN secret')
        .addTag('Sync', 'Ingestion des ventes et mouvements depuis la caisse Desktop')
        .addTag('Mobile', 'Endpoints sécurisés pour le smartphone du patron')
        .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document, {
        swaggerOptions: {
            persistAuthorization: true,
            docExpansion: 'list',
            filter: true,
        },
        customSiteTitle: "N'MaShop API Swagger UI",
    });
    const port = process.env.PORT ?? 3000;
    await app.listen(port);
    console.log(`\n🚀 Serveur N'MaShop démarré sur : http://localhost:${port}`);
    console.log(`📖 Documentation Swagger disponible sur : http://localhost:${port}/api/docs\n`);
}
await bootstrap();
//# sourceMappingURL=main.js.map