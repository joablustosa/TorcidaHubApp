import 'supabase_service.dart';

/// Modelo de produto da loja.
class StoreProduct {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? category;
  final int stockQuantity;
  final bool deliveryAvailable;
  final bool pickupOnly;
  final int memberDiscountPercent;

  StoreProduct({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.category,
    required this.stockQuantity,
    this.deliveryAvailable = false,
    this.pickupOnly = true,
    this.memberDiscountPercent = 0,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      deliveryAvailable: json['delivery_available'] as bool? ?? false,
      pickupOnly: json['pickup_only'] as bool? ?? true,
      memberDiscountPercent:
          (json['member_discount_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Modelo de variante do produto (tamanho, cor, etc.).
/// Item do carrinho.
class CartItem {
  final StoreProduct product;
  final ProductVariant? variant;
  int quantity;
  /// Desconto percentual aplicado (ex: 10 = 10%).
  int discountPercent;

  CartItem({
    required this.product,
    this.variant,
    this.quantity = 1,
    this.discountPercent = 0,
  });

  double get unitPrice => product.price + (variant?.priceAdjustment ?? 0);

  double get discountedUnitPrice {
    if (discountPercent <= 0) return unitPrice;
    return unitPrice * (1 - discountPercent / 100);
  }

  double get totalPrice => discountedUnitPrice * quantity;
}

class ProductVariant {
  final String id;
  final String productId;
  final String name;
  final String variantType;
  final double priceAdjustment;
  final int stockQuantity;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.variantType,
    this.priceAdjustment = 0,
    this.stockQuantity = 0,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      variantType: json['variant_type'] as String,
      priceAdjustment: (json['price_adjustment'] as num?)?.toDouble() ?? 0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Serviço da loja da torcida - busca produtos e verifica recebedor.
class StoreService {
  /// Busca produtos ativos da torcida.
  static Future<List<StoreProduct>> getProducts(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select()
          .eq('fan_club_id', fanClubId)
          .eq('is_active', true)
          .order('name');

      final List<dynamic> data = response as List? ?? [];
      return data
          .map((e) => StoreProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('Erro ao buscar produtos: $e');
      return [];
    }
  }

  /// Busca variantes dos produtos.
  static Future<Map<String, List<ProductVariant>>> getVariants(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};

    try {
      final response = await SupabaseService.client
          .from('product_variants')
          .select()
          .inFilter('product_id', productIds);

      final List<dynamic> data = response as List? ?? [];
      final Map<String, List<ProductVariant>> byProduct = {};
      for (var e in data) {
        final v = ProductVariant.fromJson(Map<String, dynamic>.from(e));
        byProduct.putIfAbsent(v.productId, () => []).add(v);
      }
      return byProduct;
    } catch (e) {
      print('Erro ao buscar variantes: $e');
      return {};
    }
  }

  /// Busca imagens dos produtos (product_images).
  static Future<Map<String, List<String>>> getProductImages(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};

    try {
      final response = await SupabaseService.client
          .from('product_images')
          .select('product_id, image_url')
          .inFilter('product_id', productIds)
          .order('display_order', ascending: true);

      final List<dynamic> data = response as List? ?? [];
      final Map<String, List<String>> byProduct = {};
      for (var e in data) {
        final map = Map<String, dynamic>.from(e);
        final productId = map['product_id'] as String?;
        final imageUrl = map['image_url'] as String?;
        if (productId != null && imageUrl != null) {
          byProduct.putIfAbsent(productId, () => []).add(imageUrl);
        }
      }
      return byProduct;
    } catch (e) {
      print('Erro ao buscar imagens: $e');
      return {};
    }
  }

  /// Verifica se a torcida pode receber pagamentos (pix_key ou pagarme_recipient_id).
  static Future<bool> canReceivePayments(String fanClubId) async {
    try {
      final response = await SupabaseService.client
          .from('fan_clubs')
          .select('pix_key, pagarme_recipient_id')
          .eq('id', fanClubId)
          .maybeSingle();

      if (response == null) return false;
      final pixKey = response['pix_key'] as String?;
      final recipientId = response['pagarme_recipient_id'] as String?;
      return (pixKey != null && pixKey.trim().isNotEmpty) ||
          (recipientId != null && recipientId.trim().isNotEmpty);
    } catch (e) {
      print('Erro ao verificar recebedor: $e');
      return false;
    }
  }

  /// Cria pedido e retorna PIX via create-woovi-store-payment (Woovi/OpenPix).
  /// Corresponde ao curl do front - o servidor calcula subtotal, taxas e total.
  static Future<Map<String, dynamic>?> createWooviStorePayment({
    required String fanClubId,
    required List<Map<String, dynamic>> items,
    required String deliveryMethod,
    String? deliveryAddress,
    String? deliveryCity,
    String? deliveryState,
    String? deliveryZip,
    required String customerPhone,
    String? customerNotes,
  }) async {
    try {
      final body = <String, dynamic>{
        'fan_club_id': fanClubId,
        'items': items,
        'delivery_method': deliveryMethod,
        'delivery_address': deliveryAddress,
        'delivery_city': deliveryCity,
        'delivery_state': deliveryState,
        'delivery_zip': deliveryZip,
        'customer_phone': customerPhone,
        'customer_notes': customerNotes,
      };

      final response = await SupabaseService.client.functions.invoke(
        'create-woovi-store-payment',
        body: body,
      );

      if (response.status != 200) {
        final err = response.data;
        final msg = err is Map && err['error'] != null
            ? err['error'].toString()
            : 'Erro ao processar pagamento (${response.status})';
        throw Exception(msg);
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) {
        throw Exception(data?['error'] ?? 'Erro ao processar pagamento');
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }
}
