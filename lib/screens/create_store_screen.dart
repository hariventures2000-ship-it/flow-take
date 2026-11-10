import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/store_model.dart';
import '../services/auth_service.dart';
import '../services/domain_config.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import 'store_created_success_screen.dart';

class CreateStoreScreen extends StatefulWidget {
  final AppUserProfile user;
  final AuthService authService;
  final StoreService storeService;

  const CreateStoreScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.storeService,
  });

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();

  String _selectedCategory = 'Food & Beverages';
  String _selectedCountry = 'India';
  String _selectedCurrency = 'INR';

  bool _isSlugManuallyEdited = false;
  SlugCheckStatus _slugStatus = SlugCheckStatus.idle;
  String? _slugErrorMessage;
  Timer? _debounceTimer;

  bool _isLoading = false;
  String? _generalError;

  final List<String> _categories = [
    'Fashion & Clothing',
    'Food & Beverages',
    'Electronics',
    'Beauty & Cosmetics',
    'Grocery',
    'Home & Living',
    'Digital Products',
    'Services',
    'Other',
  ];

  final List<Map<String, String>> _countries = [
    {'name': 'India', 'currency': 'INR', 'flag': '🇮🇳', 'code': '+91'},
    {'name': 'United States', 'currency': 'USD', 'flag': '🇺🇸', 'code': '+1'},
    {'name': 'United Kingdom', 'currency': 'GBP', 'flag': '🇬🇧', 'code': '+44'},
    {'name': 'United Arab Emirates', 'currency': 'AED', 'flag': '🇦🇪', 'code': '+971'},
    {'name': 'Singapore', 'currency': 'SGD', 'flag': '🇸🇬', 'code': '+65'},
    {'name': 'Malaysia', 'currency': 'MYR', 'flag': '🇲🇾', 'code': '+60'},
    {'name': 'Indonesia', 'currency': 'IDR', 'flag': '🇮🇩', 'code': '+62'},
    {'name': 'Canada', 'currency': 'CAD', 'flag': '🇨🇦', 'code': '+1'},
    {'name': 'Australia', 'currency': 'AUD', 'flag': '🇦🇺', 'code': '+61'},
  ];

  @override
  void initState() {
    super.initState();
    _storeNameController.addListener(_onStoreNameChanged);
    _slugController.addListener(_onSlugInputChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _storeNameController.removeListener(_onStoreNameChanged);
    _slugController.removeListener(_onSlugInputChanged);
    _storeNameController.dispose();
    _slugController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _onStoreNameChanged() {
    if (!_isSlugManuallyEdited) {
      final generated = DomainConfig.generateSlug(_storeNameController.text);
      if (generated != _slugController.text) {
        _slugController.text = generated;
      }
    }
  }

  void _onSlugInputChanged() {
    _debounceTimer?.cancel();
    final slug = _slugController.text.trim();

    if (slug.isEmpty) {
      setState(() {
        _slugStatus = SlugCheckStatus.idle;
        _slugErrorMessage = null;
      });
      return;
    }

    final validation = DomainConfig.validateSlug(slug);
    if (!validation.isValid) {
      setState(() {
        _slugStatus = SlugCheckStatus.invalid;
        _slugErrorMessage = validation.error;
      });
      return;
    }

    setState(() {
      _slugStatus = SlugCheckStatus.checking;
      _slugErrorMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final status = await widget.storeService.checkSlugAvailability(slug);
      if (mounted && _slugController.text.trim() == slug) {
        setState(() {
          _slugStatus = status;
          if (status == SlugCheckStatus.taken) {
            _slugErrorMessage = 'Username already taken. Please pick another.';
          } else {
            _slugErrorMessage = null;
          }
        });
      }
    });
  }

  Future<void> _handleCreateStore() async {
    if (!_formKey.currentState!.validate()) return;

    if (_slugStatus != SlugCheckStatus.available) {
      // Force check if user typed fast
      final status = await widget.storeService.checkSlugAvailability(_slugController.text.trim());
      if (status != SlugCheckStatus.available) {
        setState(() {
          _slugStatus = status;
          _slugErrorMessage = status == SlugCheckStatus.taken
              ? 'Username already taken.'
              : 'Please enter a valid username.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final store = await widget.storeService.createStore(
        ownerId: widget.user.uid,
        storeName: _storeNameController.text.trim(),
        storeSlug: _slugController.text.trim(),
        category: _selectedCategory,
        whatsappNumber: _whatsappController.text.trim(),
        country: _selectedCountry,
        currency: _selectedCurrency,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StoreCreatedSuccessScreen(
              store: store,
              user: widget.user,
              authService: widget.authService,
              storeService: widget.storeService,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _generalError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewSlug = _slugController.text.trim().isEmpty ? 'your-store' : _slugController.text.trim();
    final liveUrl = DomainConfig.buildStoreUrl(previewSlug);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('New Store'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () => widget.authService.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal Header inspired by Take.app
                const Text(
                  'Create your online store',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set up your store and start selling online in minutes.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                if (_generalError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 20, color: AppTheme.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _generalError!,
                            style: const TextStyle(color: AppTheme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Store Name
                _buildFieldLabel('Store Name'),
                TextFormField(
                  controller: _storeNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    hintText: 'e.g. Fresh Mart, Urban Vogue',
                    prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your store name';
                    }
                    if (val.trim().length < 2) {
                      return 'Store name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Subdomain / Store Username
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFieldLabel('Store Subdomain / Username'),
                    if (_slugStatus == SlugCheckStatus.checking)
                      const Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          ),
                          SizedBox(width: 6),
                          Text('Checking...', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      )
                    else if (_slugStatus == SlugCheckStatus.available)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Username available', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
                TextFormField(
                  controller: _slugController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
                  ],
                  onChanged: (_) {
                    _isSlugManuallyEdited = true;
                  },
                  decoration: _inputDecoration(
                    hintText: 'e.g. fresh-mart',
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  ),
                  validator: (val) {
                    final res = DomainConfig.validateSlug(val ?? '');
                    if (!res.isValid) return res.error;
                    if (_slugStatus == SlugCheckStatus.taken) return 'This username is already taken';
                    return null;
                  },
                ),
                if (_slugErrorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(_slugErrorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                ],
                const SizedBox(height: 8),

                // Live Domain Preview Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public, size: 18, color: AppTheme.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Store URL Preview',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              liveUrl,
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
                      if (DomainConfig.isLocalhost)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Local Dev',
                            style: TextStyle(fontSize: 10, color: Colors.brown, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Business Category
                _buildFieldLabel('Business Category'),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _inputDecoration(
                    prefixIcon: const Icon(Icons.category_outlined, size: 20),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 20),

                // WhatsApp Business Number
                _buildFieldLabel('WhatsApp Business Number'),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    hintText: 'e.g. 9876543210 (without country code)',
                    prefixIcon: const Icon(Icons.chat_bubble_outline, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'WhatsApp number is required for customer order delivery';
                    }
                    if (val.trim().length < 7) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Country & Currency
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Country'),
                          DropdownButtonFormField<String>(
                            value: _selectedCountry,
                            isExpanded: true,
                            decoration: _inputDecoration(),
                            items: _countries.map((c) {
                              return DropdownMenuItem(
                                value: c['name'],
                                child: Text('${c['flag']} ${c['name']}', style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final match = _countries.firstWhere((c) => c['name'] == val);
                                setState(() {
                                  _selectedCountry = val;
                                  _selectedCurrency = match['currency']!;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Currency'),
                          DropdownButtonFormField<String>(
                            value: _selectedCurrency,
                            decoration: _inputDecoration(),
                            items: ['INR', 'USD', 'GBP', 'AED', 'SGD', 'MYR', 'EUR'].map((curr) {
                              return DropdownMenuItem(
                                value: curr,
                                child: Text(curr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCurrency = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreateStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandBlack,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                          )
                        : const Text(
                            'Create store',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: AppTheme.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.brandBlack, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.8),
      ),
    );
  }
}

