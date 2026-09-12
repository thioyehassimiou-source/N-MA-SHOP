import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_contacts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.containerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Centre d\'Aide',
                subtitle: 'Apprenez à maîtriser N\'MaShop en quelques minutes',
                icon: Icons.help_outline_rounded,
                gradientColors: const [Color(0xFF0F1B3D), Color(0xFF1A2B52)],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Quick Actions ────────────────────────────────────────────
              _QuickActionGrid(),
              const SizedBox(height: AppSpacing.xl),

              // ── Sections FAQ ─────────────────────────────────────────────
              for (final section in _helpSections) ...[
                _SectionHeader(icon: section.icon, title: section.title, color: section.color),
                const SizedBox(height: AppSpacing.md),
                for (final item in section.items)
                  _FaqTile(
                    id: item.id,
                    question: item.question,
                    answer: item.answer,
                    isExpanded: _expandedId == item.id,
                    onTap: () {
                      setState(() {
                        _expandedId = _expandedId == item.id ? null : item.id;
                      });
                    },
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Contact Support ─────────────────────────────────────────
              _buildContactSupportCard(context),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactSupportCard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: context.colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icône du support
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.brandOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Textes et coordonnées
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Besoin d\'aide supplémentaire ?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Contactez le support technique N\'MaShop via WhatsApp, téléphone ou email.',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _ContactPill(
                                icon: Icons.person_outline_rounded,
                                label: AppContacts.developerName,
                                detail: 'Concepteur',
                              ),
                              _ContactPill(
                                icon: Icons.phone_android_rounded,
                                label: AppContacts.phone,
                                onTap: () => UrlLauncherHelper.openUrl('tel:${AppContacts.phoneRaw}'),
                              ),
                              _ContactPill(
                                icon: Icons.alternate_email_rounded,
                                label: AppContacts.email,
                                onTap: () => UrlLauncherHelper.openUrl('mailto:${AppContacts.email}?subject=Support%20NMaShop'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),

                    // Actions parfaitement alignées à droite
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => UrlLauncherHelper.openUrl('tel:${AppContacts.phoneRaw}'),
                          icon: const Icon(Icons.phone_rounded, size: 15),
                          label: const Text('Appeler'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => UrlLauncherHelper.openUrl('mailto:${AppContacts.email}?subject=Support%20NMaShop'),
                          icon: const Icon(Icons.email_outlined, size: 15),
                          label: const Text('Email'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => UrlLauncherHelper.openUrl(AppContacts.getWhatsAppSupportUrl()),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                          label: const Text('WhatsApp'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.brandOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: AppColors.brandOrange,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Besoin d\'aide supplémentaire ?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Contactez le support technique N\'MaShop via WhatsApp, téléphone ou email.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ContactPill(
                          icon: Icons.person_outline_rounded,
                          label: AppContacts.developerName,
                          detail: 'Concepteur',
                        ),
                        _ContactPill(
                          icon: Icons.phone_android_rounded,
                          label: AppContacts.phone,
                          onTap: () => UrlLauncherHelper.openUrl('tel:${AppContacts.phoneRaw}'),
                        ),
                        _ContactPill(
                          icon: Icons.alternate_email_rounded,
                          label: AppContacts.email,
                          onTap: () => UrlLauncherHelper.openUrl('mailto:${AppContacts.email}?subject=Support%20NMaShop'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => UrlLauncherHelper.openUrl('tel:${AppContacts.phoneRaw}'),
                          icon: const Icon(Icons.phone_rounded, size: 15),
                          label: const Text('Appeler'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => UrlLauncherHelper.openUrl('mailto:${AppContacts.email}?subject=Support%20NMaShop'),
                          icon: const Icon(Icons.email_outlined, size: 15),
                          label: const Text('Email'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => UrlLauncherHelper.openUrl(AppContacts.getWhatsAppSupportUrl()),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                          label: const Text('WhatsApp'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ContactPill extends StatelessWidget {
  const _ContactPill({
    required this.icon,
    required this.label,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 4),
            Text(
              '($detail)',
              style: TextStyle(
                fontSize: 11,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: pill,
      );
    }
    return pill;
  }
}

// ── Quick Action Grid ────────────────────────────────────────────────────────

class _QuickActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(Icons.shopping_cart_rounded, 'Faire une vente', const Color(0xFF10B981), '/vendre'),
      _QuickAction(Icons.inventory_2_rounded, 'Ajouter un produit', const Color(0xFF3B82F6), '/produits'),
      _QuickAction(Icons.people_rounded, 'Gérer les clients', const Color(0xFF8B5CF6), '/clients'),
      _QuickAction(Icons.bar_chart_rounded, 'Voir les rapports', const Color(0xFFF59E0B), '/rapports'),
      _QuickAction(Icons.save_alt_rounded, 'Sauvegarder les données', const Color(0xFFEF4444), '/reglages'),
      _QuickAction(Icons.settings_rounded, 'Configurer la boutique', const Color(0xFF6B7280), '/reglages'),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.2,
      children: actions.map((a) => _QuickActionCard(action: a)).toList(),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.color, this.path);
  final IconData icon;
  final String label;
  final Color color;
  final String path;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go(action.path),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(action.icon, color: action.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(action.label,
                style: AppTypography.bodySm
                    .copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});
  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title,
            style: AppTypography.labelMd
                .copyWith(color: context.colors.onSurface)),
      ],
    );
  }
}

// ── FAQ Tile ─────────────────────────────────────────────────────────────────

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.id,
    required this.question,
    required this.answer,
    required this.isExpanded,
    required this.onTap,
  });

  final String id;
  final String question;
  final String answer;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isExpanded
              ? context.colors.primaryContainer.withValues(alpha: 0.3)
              : context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isExpanded
                ? context.colors.primary.withValues(alpha: 0.3)
                : context.colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(question,
                          style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface)),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: AppSpacing.md),
                  Divider(
                      color: context.colors.outlineVariant, height: 1),
                  const SizedBox(height: AppSpacing.md),
                  Text(answer,
                      style: AppTypography.bodySm
                          .copyWith(color: context.colors.onSurfaceVariant,
                          height: 1.6)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _HelpSection {
  const _HelpSection(
      {required this.icon,
      required this.title,
      required this.color,
      required this.items});
  final IconData icon;
  final String title;
  final Color color;
  final List<_HelpItem> items;
}

class _HelpItem {
  const _HelpItem(
      {required this.id, required this.question, required this.answer});
  final String id;
  final String question;
  final String answer;
}

const _helpSections = [
  _HelpSection(
    icon: Icons.shopping_cart_rounded,
    title: 'Effectuer une Vente',
    color: Color(0xFF10B981),
    items: [
      _HelpItem(
        id: 'vente_1',
        question: 'Comment enregistrer une vente ?',
        answer:
            '1. Cliquez sur "Vente" dans le menu de gauche.\n'
            '2. Sélectionnez les produits en cliquant dessus dans la liste.\n'
            '3. Ajustez la quantité en cliquant sur le bouton "+" ou "−".\n'
            '4. Choisissez le mode de paiement (Espèces, Mobile Money, etc.).\n'
            '5. Saisissez le montant reçu du client.\n'
            '6. Validez la vente en cliquant sur "Encaisser".',
      ),
      _HelpItem(
        id: 'vente_2',
        question: 'Comment générer et imprimer une facture ?',
        answer:
            'Après avoir validé la vente, un bouton "Imprimer le reçu" s\'affiche automatiquement.\n'
            'Cliquez dessus pour générer le document PDF au format A4.\n'
            'Vous pouvez ensuite l\'imprimer ou le sauvegarder sur votre ordinateur.',
      ),
      _HelpItem(
        id: 'vente_3',
        question: 'Un client ne paie pas tout de suite, que faire ?',
        answer:
            'Si le client ne paie pas la totalité, entrez le montant partiel qu\'il vous donne.\n'
            'L\'application va automatiquement créer un "Crédit" pour le montant restant.\n'
            'Ce crédit sera visible dans l\'onglet "Crédits" lié au client.',
      ),
    ],
  ),
  _HelpSection(
    icon: Icons.inventory_2_rounded,
    title: 'Gestion du Stock et Produits',
    color: Color(0xFF3B82F6),
    items: [
      _HelpItem(
        id: 'stock_1',
        question: 'Comment ajouter un nouveau produit ?',
        answer:
            '1. Allez dans "Stock" depuis le menu principal.\n'
            '2. Cliquez sur le bouton "Nouveau Produit" (coin supérieur droit).\n'
            '3. Remplissez les informations : Nom, Référence, Prix d\'achat, Prix de vente, Quantité en stock.\n'
            '4. Vous pouvez aussi ajouter une photo en cliquant sur l\'icône image.\n'
            '5. Définissez un "Seuil d\'alerte" pour être averti quand le stock est bas.\n'
            '6. Cliquez sur "Enregistrer".',
      ),
      _HelpItem(
        id: 'stock_2',
        question: 'Comment importer mes produits en masse depuis Excel ?',
        answer:
            '1. Préparez un fichier Excel (ou CSV) avec les colonnes : Nom ; Référence ; Unité ; Prix Achat ; Prix Vente ; Stock ; Seuil.\n'
            '2. Sauvegardez-le au format .csv (séparé par des point-virgules).\n'
            '3. Dans l\'écran "Stock", cliquez sur "Importer".\n'
            '4. Sélectionnez votre fichier CSV. Les produits seront ajoutés automatiquement.',
      ),
      _HelpItem(
        id: 'stock_3',
        question: 'L\'alerte de stock bas est-elle automatique ?',
        answer:
            'Oui ! Quand le niveau de stock d\'un produit descend en dessous du "Seuil d\'alerte" que vous avez défini, '
            'la ligne de ce produit s\'affiche en rouge dans le tableau de stock '
            'et une alerte apparaît dans le tableau de bord principal.',
      ),
    ],
  ),
  _HelpSection(
    icon: Icons.people_rounded,
    title: 'Clients et Crédits',
    color: Color(0xFF8B5CF6),
    items: [
      _HelpItem(
        id: 'client_1',
        question: 'Comment enregistrer un nouveau client ?',
        answer:
            '1. Allez dans "Clients" depuis le menu.\n'
            '2. Cliquez sur "Nouveau Client".\n'
            '3. Renseignez le nom, le téléphone et l\'adresse du client.\n'
            '4. Le client sera disponible lors de vos prochaines ventes.',
      ),
      _HelpItem(
        id: 'client_2',
        question: 'Comment voir ce qu\'un client me doit ?',
        answer:
            '1. Allez dans l\'onglet "Crédits".\n'
            '2. Vous verrez la liste de tous les clients qui ont un solde en attente.\n'
            '3. Cliquez sur un client pour voir le détail de ses dettes.\n'
            '4. Lorsqu\'il paie, cliquez sur "Enregistrer un remboursement" pour mettre à jour son solde.',
      ),
    ],
  ),
  _HelpSection(
    icon: Icons.save_alt_rounded,
    title: 'Sauvegardes et Sécurité',
    color: Color(0xFFEF4444),
    items: [
      _HelpItem(
        id: 'backup_1',
        question: 'Comment sauvegarder mes données pour ne pas les perdre ?',
        answer:
            'Il est fortement conseillé de faire une sauvegarde régulière (chaque semaine ou chaque mois).\n\n'
            '1. Allez dans "Paramètres" > onglet "Sécurité".\n'
            '2. Cliquez sur "Sauvegarder la base de données".\n'
            '3. Choisissez un emplacement (Dossier Documents, clé USB, etc.).\n'
            '4. Le fichier .sqlite généré contient TOUTES vos données.',
      ),
      _HelpItem(
        id: 'backup_2',
        question: 'Comment exporter mes ventes pour mon comptable ?',
        answer:
            '1. Allez dans "Paramètres" > onglet "Sécurité".\n'
            '2. Cliquez sur "Exporter les ventes (CSV)".\n'
            '3. Choisissez où sauvegarder le fichier.\n'
            '4. Ouvrez ce fichier dans Excel ou Libre Office Calc pour voir toutes vos ventes.',
      ),
    ],
  ),
  _HelpSection(
    icon: Icons.settings_rounded,
    title: 'Configuration et Paramètres',
    color: Color(0xFF6B7280),
    items: [
      _HelpItem(
        id: 'config_1',
        question: 'Comment changer le nom ou le logo de ma boutique ?',
        answer:
            '1. Allez dans "Paramètres" > onglet "Profil".\n'
            '2. Cliquez sur le logo (cercle en haut) pour choisir une image.\n'
            '3. Modifiez le nom, le téléphone, l\'adresse et le NIF.\n'
            '4. Cliquez sur "Enregistrer". Les informations apparaîtront sur vos factures.',
      ),
      _HelpItem(
        id: 'config_2',
        question: 'Comment changer l\'apparence (thème clair/sombre) ?',
        answer:
            '1. Allez dans "Paramètres" > onglet "Apparence".\n'
            '2. Choisissez une palette de couleurs dans la liste proposée.\n'
            '3. Le changement s\'applique immédiatement à toute l\'application, sans redémarrage.',
      ),
      _HelpItem(
        id: 'config_3',
        question: 'Comment créer un compte pour mon caissier ?',
        answer:
            '1. Allez dans "Équipe" depuis le menu principal.\n'
            '2. Cliquez sur "Ajouter un membre".\n'
            '3. Choisissez le rôle "Caissier/Vendeur" — ce rôle limite les accès aux fonctions sensibles.\n'
            '4. Définissez un mot de passe pour le nouveau compte.',
      ),
    ],
  ),
];
