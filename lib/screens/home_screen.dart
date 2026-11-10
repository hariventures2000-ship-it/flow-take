import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../services/auth_service.dart';
import '../services/domain_config.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';
import 'create_store_screen.dart';
import 'customize_store_screen.dart';
import 'store_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUserProfile user;
  final AuthService authService;
  final String? initialStoreId;

  const HomeScreen({
    super.key,
    required this.user,
    required this.authService,
    this.initialStoreId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StoreService _storeService = StoreService();

  List<StoreModel> _userStores = [];
  StoreModel? _selectedStore;
  List<ProductModel> _products = [];

  bool _isLoadingStores = true;
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoadingStores = true);

    try {
      final stores = await _storeService.getUserStores(widget.user.uid);
      if (!mounted) return;

      if (stores.isEmpty) {
        // If user has no store, route immediately to CreateStoreScreen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CreateStoreScreen(
                user: widget.user,
                authService: widget.authService,
                storeService: _storeService,
              ),
            ),
          );
        });
        return;
      }

      // Determine active store
      StoreModel selected;
      final savedStoreId = widget.initialStoreId ?? await _storeService.getActiveStoreId();

      if (savedStoreId != null && stores.any((s) => s.id == savedStoreId)) {
        selected = stores.firstWhere((s) => s.id == savedStoreId);
      } else {
        selected = stores.first;
      }

      await _storeService.setActiveStoreId(selected.id);

      setState(() {
        _userStores = stores;
        _selectedStore = selected;
        _isLoadingStores = false;
      });

      _loadProducts(selected.id);
    } catch (e) {
      debugPrint('[HomeScreen] loadStores error: $e');
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _loadProducts(String storeId) async {
    setState(() => _isLoadingProducts = true);
    try {
      final prods = await _storeService.getStoreProducts(storeId);
      if (mounted) {
        setState(() {
          _products = prods;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _switchStore(StoreModel newStore) async {
    await _storeService.setActiveStoreId(newStore.id);
    setState(() {
      _selectedStore = newStore;
    });
    _loadProducts(newStore.id);
  }

  void _showStoreSwitcherBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Stores',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._userStores.map((store) {
                  final isSelected = store.id == _selectedStore?.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.brandBlack,
                      backgroundImage: store.logoUrl != null ? NetworkImage(store.logoUrl!) : null,
                      child: store.logoUrl == null
                          ? Text(
                              store.storeName.isNotEmpty ? store.storeName[0].toUpperCase() : 'S',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    title: Text(
                      store.storeName,
                      style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                    ),
                    subtitle: Text(
                      DomainConfig.buildStoreUrl(store.storeSlug),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _switchStore(store);
                    },
                  );
                }),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.border,
                    child: Icon(Icons.add, color: AppTheme.brandBlack),
                  ),
                  title: const Text('Add another store', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateStoreScreen(
                          user: widget.user,
                          authService: widget.authService,
                          storeService: _storeService,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStores) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.brandBlack, strokeWidth: 2.2),
        ),
      );
    }

    final store = _selectedStore;
    if (store == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: ElevatedButton(
            onPressed: () => _loadStores(),
            child: const Text('Retry loading store'),
          ),
        ),
      );
    }

    final storeUrl = DomainConfig.buildStoreUrl(store.storeSlug);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _showStoreSwitcherBottomSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.brandBlack,
                  backgroundImage: store.logoUrl != null ? NetworkImage(store.logoUrl!) : null,
                  child: store.logoUrl == null
                      ? Text(
                          store.storeName.isNotEmpty ? store.storeName[0].toUpperCase() : 'S',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    store.storeName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Copy Store URL',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: storeUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $storeUrl'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Sign out?', style: TextStyle(fontWeight: FontWeight.w700)),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandBlack,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _storeService.clearActiveStoreId();
                await widget.authService.signOut();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadStores();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Live URL Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlack.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.public, color: AppTheme.brandBlack, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Your Store Link',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 6),
                                if (DomainConfig.isLocalhost)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Dev Subdomain',
                                      style: TextStyle(fontSize: 9, color: Colors.brown, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              storeUrl,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.brandBlack,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy Store Link',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: storeUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied: $storeUrl'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Metrics / Store Overview
                const Text(
                  'Store Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),

                // 2x2 Metric Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Sales',
                        value: '${store.currency} 0.00',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Orders',
                        value: '0',
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Pending Orders',
                        value: '0',
                        icon: Icons.hourglass_top_outlined,
                        badgeColor: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Completed Orders',
                        value: '0',
                        icon: Icons.task_alt_outlined,
                        badgeColor: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Products',
                        value: '${_products.length}',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Customers',
                        value: '0',
                        icon: Icons.people_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                // Store Management Shortcuts
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Add Product',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddProductScreen(
                                store: store,
                                user: widget.user,
                                authService: widget.authService,
                                storeService: _storeService,
                              ),
                            ),
                          ).then((_) => _loadProducts(store.id));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.tune_rounded,
                        label: 'Customize',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomizeStoreScreen(
                                store: store,
                                user: widget.user,
                                authService: widget.authService,
                                storeService: _storeService,
                              ),
                            ),
                          ).then((_) => _loadStores());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.storefront_outlined,
                        label: 'All Stores',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoreSelectionScreen(
                                stores: _userStores,
                                user: widget.user,
                                authService: widget.authService,
                                storeService: _storeService,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Product Catalog Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Store Products',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add item', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddProductScreen(
                              store: store,
                              user: widget.user,
                              authService: widget.authService,
                              storeService: _storeService,
                            ),
                          ),
                        ).then((_) => _loadProducts(store.id));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoadingProducts)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_products.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 38, color: AppTheme.textMuted),
                        const SizedBox(height: 10),
                        const Text(
                          'No products yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add your first item so customers can start buying on WhatsApp.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add product'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandBlack,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddProductScreen(
                                  store: store,
                                  user: widget.user,
                                  authService: widget.authService,
                                  storeService: _storeService,
                                ),
                              ),
                            ).then((_) => _loadProducts(store.id));
                          },
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final prod = _products[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                                image: prod.images.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(prod.images.first), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: prod.images.isEmpty
                                  ? const Icon(Icons.inventory_2_outlined, size: 22, color: AppTheme.textMuted)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${store.currency} ${prod.sellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.brandBlack),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: prod.isAvailable ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                prod.isAvailable ? 'In Stock (${prod.stockQuantity})' : 'Sold out',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: prod.isAvailable ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondary),
              if (badgeColor != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppTheme.brandBlack),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
