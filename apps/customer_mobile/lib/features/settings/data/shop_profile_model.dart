class ShopProfile {
  final String shopName;
  final String phoneNumber;
  final String managerName;
  final String address;
  final String currency; // 'GNF', 'XOF', 'USD', 'EUR'
  final String? logoPath;

  const ShopProfile({
    this.shopName = 'Ma Boutique',
    this.phoneNumber = '',
    this.managerName = 'Administrateur',
    this.address = '',
    this.currency = 'GNF',
    this.logoPath,
  });

  ShopProfile copyWith({
    String? shopName,
    String? phoneNumber,
    String? managerName,
    String? address,
    String? currency,
    String? logoPath,
  }) {
    return ShopProfile(
      shopName: shopName ?? this.shopName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      managerName: managerName ?? this.managerName,
      address: address ?? this.address,
      currency: currency ?? this.currency,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}
