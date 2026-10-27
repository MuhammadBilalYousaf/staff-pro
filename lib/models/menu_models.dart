class MenuChoice {
  MenuChoice({required this.id, required this.name, required this.price});

  final String id;
  String name;
  double price;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};

  factory MenuChoice.fromJson(Map<String, dynamic> json) {
    return MenuChoice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MenuProduct {
  MenuProduct({
    required this.id,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    required this.price,
    this.available = true,
    List<MenuChoice>? variants,
    List<MenuChoice>? addons,
  })  : variants = variants ?? [],
        addons = addons ?? [];

  final String id;
  String name;
  String description;
  String imageUrl;
  /// Used when [variants] is empty. When variants exist, each variant price is the full price.
  double price;
  bool available;
  List<MenuChoice> variants;
  List<MenuChoice> addons;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'price': price,
        'available': available,
        'variants': variants.map((e) => e.toJson()).toList(),
        'addons': addons.map((e) => e.toJson()).toList(),
      };

  factory MenuProduct.fromJson(Map<String, dynamic> json) {
    List<MenuChoice> choices(dynamic raw) {
      if (raw is! List) return [];
      return raw.whereType<Map>().map((e) => MenuChoice.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    return MenuProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      available: json['available'] != false,
      variants: choices(json['variants']),
      addons: choices(json['addons']),
    );
  }
}

class MenuCategory {
  MenuCategory({
    required this.id,
    required this.name,
    this.sort = 0,
    this.active = true,
    List<MenuProduct>? products,
  }) : products = products ?? [];

  final String id;
  String name;
  int sort;
  bool active;
  List<MenuProduct> products;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sort': sort,
        'active': active,
        'products': products.map((e) => e.toJson()).toList(),
      };

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    final raw = json['products'];
    return MenuCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sort: (json['sort'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
      products: raw is List
          ? raw.whereType<Map>().map((e) => MenuProduct.fromJson(Map<String, dynamic>.from(e))).toList()
          : [],
    );
  }
}

class PublicBusiness {
  PublicBusiness({
    required this.slug,
    required this.businessId,
    required this.name,
    this.branchId,
    this.status = 'active',
    this.paymentAccountName = '',
    this.paymentAccountNumber = '',
    this.paymentInstructions = '',
  });

  final String slug;
  final String businessId;
  String name;
  String? branchId;
  String status;
  String paymentAccountName;
  String paymentAccountNumber;
  String paymentInstructions;

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'businessId': businessId,
        'name': name,
        'branchId': branchId,
        'status': status,
        'paymentAccountName': paymentAccountName,
        'paymentAccountNumber': paymentAccountNumber,
        'paymentInstructions': paymentInstructions,
      };

  factory PublicBusiness.fromJson(Map<String, dynamic> json) {
    return PublicBusiness(
      slug: json['slug']?.toString() ?? '',
      businessId: json['businessId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      branchId: json['branchId']?.toString(),
      status: json['status']?.toString() ?? 'active',
      paymentAccountName: json['paymentAccountName']?.toString() ?? '',
      paymentAccountNumber: json['paymentAccountNumber']?.toString() ?? '',
      paymentInstructions: json['paymentInstructions']?.toString() ?? '',
    );
  }
}

class PublicMenu {
  PublicMenu({required this.businessId, List<MenuCategory>? categories, DateTime? updatedAt})
      : categories = categories ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  final String businessId;
  List<MenuCategory> categories;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'businessId': businessId,
        'updatedAt': updatedAt.toIso8601String(),
        'categories': categories.map((e) => e.toJson()).toList(),
      };

  factory PublicMenu.fromJson(Map<String, dynamic> json) {
    final raw = json['categories'];
    return PublicMenu(
      businessId: json['businessId']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      categories: raw is List
          ? raw.whereType<Map>().map((e) => MenuCategory.fromJson(Map<String, dynamic>.from(e))).toList()
          : [],
    );
  }
}
