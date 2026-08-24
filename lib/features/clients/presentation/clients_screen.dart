import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../application/clients_providers.dart';
import 'new_client_dialog.dart';

import 'package:nmashop/core/theme/app_theme.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClients = ref.watch(clientsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppPageHeader(
            title: 'Carnet Clients',
            subtitle: 'Gérez votre base de données clients et contacts',
            icon: Icons.people_outline_rounded,
            gradientColors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
            actions: [
              FilledButton.icon(
                onPressed: () => NewClientDialog.show(context),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Nouveau Client'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: asyncClients.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (clients) {
              if (clients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: context.colors.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Aucun client enregistré', style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 16)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final c = clients[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                c.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (c.phone != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    c.phone!,
                                    style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 13),
                                  ),
                                ],
                                if (c.address != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    c.address!,
                                    style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 13),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          if (c.phone != null) ...[
                            IconButton(
                              tooltip: 'Appeler',
                              icon: const Icon(Icons.phone_outlined, color: Colors.green),
                              onPressed: () => launchUrl(Uri.parse('tel:${c.phone}')),
                            ),
                            IconButton(
                              tooltip: 'WhatsApp',
                              icon: const Icon(Icons.chat_outlined, color: Colors.teal),
                              onPressed: () => launchUrl(Uri.parse('https://wa.me/${c.phone}')),
                            ),
                          ],
                          IconButton(
                            tooltip: 'Modifier',
                            icon: Icon(Icons.edit_outlined, color: context.colors.onSurfaceVariant),
                            onPressed: () => NewClientDialog.show(context, client: c),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
