import 'package:flutter/material.dart';
import '../models/store_model.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import 'create_store_screen.dart';
import 'home_screen.dart';
import 'store_selection_screen.dart';

/// Decides whether to route the authenticated user to:
/// 1. CreateStoreScreen (if user has 0 stores)
/// 2. HomeScreen (if user has 1 store)
/// 3. StoreSelectionScreen (if user has multiple stores)
class StoreGateRouter extends StatefulWidget {
  final AppUserProfile user;
  final AuthService authService;

  const StoreGateRouter({
    super.key,
    required this.user,
    required this.authService,
  });

  @override
  State<StoreGateRouter> createState() => _StoreGateRouterState();
}

class _StoreGateRouterState extends State<StoreGateRouter> {
  final StoreService _storeService = StoreService();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolveUserNavigation();
  }

  Future<void> _resolveUserNavigation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stores = await _storeService.getUserStores(widget.user.uid);

      if (!mounted) return;

      if (stores.isEmpty) {
        // User has no stores -> Create Your Store
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreateStoreScreen(
              user: widget.user,
              authService: widget.authService,
              storeService: _storeService,
            ),
          ),
        );
      } else if (stores.length == 1) {
        // User has exactly one store -> open its dashboard directly
        final singleStore = stores.first;
        await _storeService.setActiveStoreId(singleStore.id);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              user: widget.user,
              authService: widget.authService,
              initialStoreId: singleStore.id,
            ),
          ),
        );
      } else {
        // User has multiple stores -> Store Selection Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StoreSelectionScreen(
              stores: stores,
              user: widget.user,
              authService: widget.authService,
              storeService: _storeService,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[StoreGateRouter] Navigation resolution error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40, color: AppTheme.error),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _resolveUserNavigation,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlack),
                  child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: AppTheme.brandBlack, strokeWidth: 2.2),
            ),
            SizedBox(height: 14),
            Text(
              'Loading your store...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

