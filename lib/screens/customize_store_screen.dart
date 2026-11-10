import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/store_model.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';
import 'home_screen.dart';

class CustomizeStoreScreen extends StatefulWidget {
  final StoreModel store;
  final AppUserProfile user;
  final AuthService authService;
  final StoreService storeService;

  const CustomizeStoreScreen({
    super.key,
    required this.store,
    required this.user,
    required this.authService,
    required this.storeService,
  });

  @override
  State<CustomizeStoreScreen> createState() => _CustomizeStoreScreenState();
}

class _CustomizeStoreScreenState extends State<CustomizeStoreScreen> {
  late TextEditingController _descController;
  late TextEditingController _addressController;

  late bool _pickupEnabled;
  late bool _deliveryEnabled;
  late String _selectedBrandColor;
  String? _logoUrl;
  String? _bannerUrl;

  bool _isUploadingLogo = false;
  bool _isUploadingBanner = false;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  final List<String> _brandColors = [
    '#111827', // Black
    '#2563EB', // Blue
    '#059669', // Emerald
    '#DC2626', // Red
    '#7C3AED', // Violet
    '#D97706', // Amber
    '#DB2777', // Pink
    '#0891B2', // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.store.description ?? '');
    _addressController = TextEditingController(text: widget.store.address ?? '');
    _pickupEnabled = widget.store.pickupEnabled;
    _deliveryEnabled = widget.store.deliveryEnabled;
    _selectedBrandColor = widget.store.brandColor;
    _logoUrl = widget.store.logoUrl;
    _bannerUrl = widget.store.bannerUrl;
  }

  @override
  void dispose() {
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (picked == null) return;

      setState(() => _isUploadingLogo = true);
      final bytes = await picked.readAsBytes();
      final url = await widget.storeService.uploadStoreImage(
        storeId: widget.store.id,
        folder: 'logos',
        fileName: 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        imageFile: bytes,
      );

      setState(() {
        _logoUrl = url;
        _isUploadingLogo = false;
      });
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload logo: $e')),
      );
    }
  }

  Future<void> _pickAndUploadBanner() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 600);
      if (picked == null) return;

      setState(() => _isUploadingBanner = true);
      final bytes = await picked.readAsBytes();
      final url = await widget.storeService.uploadStoreImage(
        storeId: widget.store.id,
        folder: 'banners',
        fileName: 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
        imageFile: bytes,
      );

      setState(() {
        _bannerUrl = url;
        _isUploadingBanner = false;
      });
    } catch (e) {
      setState(() => _isUploadingBanner = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload cover: $e')),
      );
    }
  }

  Future<void> _saveCustomization({bool proceedToProduct = true}) async {
    setState(() => _isSaving = true);

    try {
      final updatedStore = await widget.storeService.updateStoreCustomization(
        storeId: widget.store.id,
        description: _descController.text.trim(),
        address: _addressController.text.trim(),
        brandColor: _selectedBrandColor,
        logoUrl: _logoUrl,
        bannerUrl: _bannerUrl,
        pickupEnabled: _pickupEnabled,
        deliveryEnabled: _deliveryEnabled,
        onboardingCompleted: true,
      );

      if (mounted) {
        if (proceedToProduct) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AddProductScreen(
                store: updatedStore,
                user: widget.user,
                authService: widget.authService,
                storeService: widget.storeService,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                user: widget.user,
                authService: widget.authService,
                initialStoreId: updatedStore.id,
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.brandBlack;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Customize Store'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _saveCustomization(proceedToProduct: true),
            child: const Text('Skip for now', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Brand & Delivery Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Personalize how your online storefront appears to customers.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Banner / Cover image
              const Text('Store Cover Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploadingBanner ? null : _pickAndUploadBanner,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                    image: _bannerUrl != null
                        ? DecorationImage(image: NetworkImage(_bannerUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _isUploadingBanner
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _bannerUrl == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 30, color: AppTheme.textMuted),
                                SizedBox(height: 6),
                                Text('Upload store banner (1200x600)', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            )
                          : Container(
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 20),

              // Store Logo
              Row(
                children: [
                  GestureDetector(
                    onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border, width: 2),
                        image: _logoUrl != null
                            ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _isUploadingLogo
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : _logoUrl == null
                              ? const Icon(Icons.camera_alt_outlined, color: AppTheme.textMuted, size: 28)
                              : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Store Logo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Upload your business logo or avatar icon', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        TextButton(
                          onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                          child: Text(_logoUrl == null ? 'Upload image' : 'Replace logo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Brand Color Picker
              const Text('Brand Accent Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _brandColors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final colorHex = _brandColors[index];
                    final color = _parseColor(colorHex);
                    final isSelected = _selectedBrandColor.toLowerCase() == colorHex.toLowerCase();

                    return GestureDetector(
                      onTap: () => setState(() => _selectedBrandColor = colorHex),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 20, color: Colors.white)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Store Description
              const Text('Store Bio / Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: _inputDecoration(
                  hintText: 'Describe your store, specialties, delivery promises or tagline...',
                ),
              ),
              const SizedBox(height: 20),

              // Store Physical Address
              const Text('Store Location / Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                decoration: _inputDecoration(
                  hintText: 'e.g. 142 MG Road, Bangalore, Karnataka',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 24),

              // Delivery & Pickup Toggles
              const Text('Fulfillment Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text('Direct Delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Send products directly to customer doorstep', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      value: _deliveryEnabled,
                      activeColor: AppTheme.brandBlack,
                      onChanged: (val) => setState(() => _deliveryEnabled = val),
                    ),
                    const Divider(height: 1, thickness: 0.8),
                    SwitchListTile.adaptive(
                      title: const Text('Store Pickup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Allow customers to collect orders at your outlet', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      value: _pickupEnabled,
                      activeColor: AppTheme.brandBlack,
                      onChanged: (val) => setState(() => _pickupEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Next Button: Add First Product
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveCustomization(proceedToProduct: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandBlack,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save & Add First Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: _isSaving ? null : () => _saveCustomization(proceedToProduct: false),
                  child: const Text('Save and skip to Dashboard', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText, Widget? prefixIcon}) {
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
    );
  }
}

