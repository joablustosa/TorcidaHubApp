import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/store_service.dart';
import '../services/membership_service.dart';
import '../constants/app_colors.dart';
import 'product_checkout_dialog.dart';

/// Seção da Loja da Torcida - produtos, carrinho, busca e categorias.
class StoreSection extends StatefulWidget {
  final String fanClubId;
  final String? memberId;

  const StoreSection({
    super.key,
    required this.fanClubId,
    this.memberId,
  });

  @override
  State<StoreSection> createState() => _StoreSectionState();
}

class _StoreSectionState extends State<StoreSection> {
  List<StoreProduct> _products = [];
  Map<String, List<ProductVariant>> _variants = {};
  Map<String, List<String>> _productImages = {};
  bool _loading = true;
  bool _canReceivePayments = false;
  String _searchTerm = '';
  String? _selectedCategory;
  final List<CartItem> _cart = [];
  bool _checkoutOpen = false;
  bool _isSubscribed = false;
  int _defaultMemberDiscount = 10;
  bool _storeDiscountEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        StoreService.getProducts(widget.fanClubId),
        StoreService.canReceivePayments(widget.fanClubId),
      ]);
      final products = results[0] as List<StoreProduct>;
      final canReceive = results[1] as bool;

      bool isSubscribed = false;
      int defaultDiscount = 10;
      bool storeDiscountEnabled = true;
      if (widget.memberId != null) {
        final sub =
            await MembershipService.getMemberSubscription(widget.memberId!);
        final access =
            await MembershipService.getAccessSettings(widget.fanClubId);
        isSubscribed = sub?.isSubscribed ?? false;
        defaultDiscount = access.settings.defaultMemberDiscount;
        storeDiscountEnabled = access.settings.storeDiscount;
      }

      List<String> productIds = products.map((p) => p.id).toList();
      final variants = await StoreService.getVariants(productIds);
      final images = await StoreService.getProductImages(productIds);

      if (mounted) {
        setState(() {
          _products = products;
          _canReceivePayments = canReceive;
          _variants = variants;
          _productImages = images;
          _isSubscribed = isSubscribed;
          _defaultMemberDiscount = defaultDiscount;
          _storeDiscountEnabled = storeDiscountEnabled;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _products = [];
          _canReceivePayments = false;
        });
      }
    }
  }

  List<String> get _categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<StoreProduct> get _filteredProducts {
    return _products.where((p) {
      final matchesSearch = _searchTerm.isEmpty ||
          p.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          (p.description?.toLowerCase().contains(_searchTerm.toLowerCase()) ??
              false);
      final matchesCategory =
          _selectedCategory == null || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  int _getProductDiscount(StoreProduct product) {
    if (!_isSubscribed || !_storeDiscountEnabled) return 0;
    if (product.memberDiscountPercent > 0) {
      return product.memberDiscountPercent;
    }
    return _defaultMemberDiscount;
  }

  void _addToCart(StoreProduct product, {ProductVariant? variant}) {
    final discount = _getProductDiscount(product);
    setState(() {
      final existing = _cart.indexWhere((item) =>
          item.product.id == product.id &&
          item.variant?.id == variant?.id);
      if (existing >= 0) {
        _cart[existing].quantity++;
      } else {
        _cart.add(CartItem(
          product: product,
          variant: variant,
          quantity: 1,
          discountPercent: discount,
        ));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicionado ao carrinho!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _updateCartQuantity(int index, int delta) {
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  double _getCartTotal() {
    return _cart.fold(0, (sum, item) => sum + item.totalPrice);
  }

  int _getCartItemCount() {
    return _cart.fold(0, (sum, item) => sum + item.quantity);
  }

  void _handleCheckoutSuccess() {
    setState(() {
      _cart.clear();
      _checkoutOpen = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pedido realizado com sucesso! Você receberá uma confirmação.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              isNarrow && _cart.isNotEmpty ? 220 : 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (!_canReceivePayments)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Loja Indisponível',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'O recebedor de pagamentos ainda não foi configurado ou aprovado. Configure nas configurações da torcida.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loja da Torcida',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Produtos oficiais',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cart.isNotEmpty && _canReceivePayments)
                  ElevatedButton.icon(
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _checkoutOpen = true);
                      });
                    },
                    icon: const Icon(Icons.shopping_cart, size: 20),
                    label: Text(
                      'Carrinho (${_getCartItemCount()}) R\$ ${_getCartTotal().toStringAsFixed(2)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (v) => setState(() => _searchTerm = v),
              decoration: InputDecoration(
                hintText: 'Buscar produtos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            if (_categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _selectedCategory == null,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = null),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                  ..._categories.map((cat) => FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                      )),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (_filteredProducts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum produto disponível',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Em breve teremos produtos disponíveis na loja',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                      constraints.maxWidth > 600 ? 3 : (constraints.maxWidth > 400 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final productVariants = _variants[product.id] ?? [];
                      final images = _productImages[product.id] ??
                          (product.imageUrl != null
                              ? [product.imageUrl!]
                              : <String>[]);
                      return _buildProductCard(
                        product: product,
                        images: images,
                        variants: productVariants,
                      );
                    },
                  );
                },
              ),
            if (_cart.isNotEmpty && !isNarrow) ...[
              const SizedBox(height: 24),
              _buildCartSummary(inFlow: true),
            ],
            ProductCheckoutDialog(
              open: _checkoutOpen,
              onOpenChange: (open) => setState(() => _checkoutOpen = open),
              cart: _cart,
              fanClubId: widget.fanClubId,
              onSuccess: _handleCheckoutSuccess,
            ),
          ],
            ),
          ),
          if (_cart.isNotEmpty && isNarrow)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildCartSummary(inFlow: false),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required StoreProduct product,
    required List<String> images,
    required List<ProductVariant> variants,
  }) {
    final hasStock = product.stockQuantity > 0 ||
        variants.any((v) => v.stockQuantity > 0);
    final canAdd = _canReceivePayments && hasStock;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: images.isEmpty
                ? Container(
                    color: AppColors.primary.withOpacity(0.08),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: images.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.primary.withOpacity(0.08),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.08),
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      if (product.pickupOnly)
                        Icon(Icons.location_on,
                            size: 14, color: AppColors.textSecondary),
                      if (product.pickupOnly) const SizedBox(width: 4),
                      if (product.pickupOnly)
                        Text(
                          'Retirada',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (product.deliveryAvailable) ...[
                        if (product.pickupOnly) const SizedBox(width: 12),
                        Icon(Icons.local_shipping,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Entrega',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final discount = _getProductDiscount(product);
                      final basePrice = product.price;
                      final displayPrice = discount > 0
                          ? basePrice * (1 - discount / 100)
                          : basePrice;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (discount > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'R\$ ${displayPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  'De R\$ ${basePrice.toStringAsFixed(2)} (-$discount%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.success,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'R\$ ${basePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          if (!hasStock)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Esgotado',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            Text(
                              '${product.stockQuantity} em estoque',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (variants.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: variants.map((v) {
                        final vHasStock = product.stockQuantity > 0 ||
                            v.stockQuantity > 0;
                        return SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: canAdd && vHasStock
                                ? () => _addToCart(product, variant: v)
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(
                                color: AppColors.primary,
                              ),
                              foregroundColor: AppColors.primary,
                            ),
                            child: Text(
                              v.priceAdjustment != 0
                                  ? '${v.name} (${v.priceAdjustment > 0 ? '+' : ''}R\$ ${v.priceAdjustment.toStringAsFixed(2)})'
                                  : v.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canAdd
                            ? () => _addToCart(product)
                            : null,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar ao Carrinho'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textLight,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cart summary conforme front: flutuante no mobile, em fluxo no desktop.
  Widget _buildCartSummary({bool inFlow = true}) {
    return Card(
      elevation: inFlow ? 2 : 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Seu Carrinho',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 192),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: _cart.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = _cart[i];
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.product.name}${item.variant != null ? ' (${item.variant!.name})' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () => _updateCartQuantity(i, -1),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(36, 36),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => _updateCartQuantity(i, 1),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(36, 36),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              'R\$ ${item.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'R\$ ${_getCartTotal().toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                    onPressed: _canReceivePayments
                        ? () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _checkoutOpen = true);
                            });
                          }
                        : null,
                child: const Text('Finalizar Compra'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
