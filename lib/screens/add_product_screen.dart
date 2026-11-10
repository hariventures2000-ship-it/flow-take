import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/store_model.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class AddProductScreen extends StatefulWidget {
  final StoreModel store;
  final AppUserProfile user;
  final AuthService authService;
  final StoreService storeService;

  const AddProductScreen({
    super.key,
    required this.store,
    required this.user,
    required this.authService,
    required this.storeService,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _comparePriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController(text: '10');
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _productCategory = 'General';
  bool _isAvailable = true;
  final List<String> _productImages = [];
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _comparePriceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
      if (picked == null) return;

      setState(() => _isUploadingImage = true);
      final bytes = await picked.readAsBytes();
      final url = await widget.storeService.uploadStoreImage(
        storeId: widget.store.id,
        folder: 'products',
        fileName: 'prod_${DateTime.now().millisecondsSinceEpoch}.jpg',
        imageFile: bytes,
      );

      setState(() {
        _productImages.add(url);
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload product image: $e')),
      );
    }
  }

  void _finishAndGoToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          user: widget.user,
          authService: widget.authService,
          initialStoreId: widget.store.id,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _handleSaveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final price = double.parse(_priceController.text.trim());
      final comparePrice = _comparePriceController.text.trim().isNotEmpty
          ? double.tryParse(_comparePriceController.text.trim())
          : null;
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;

      await widget.storeService.addProduct(
        storeId: widget.store.id,
        name: _nameController.text.trim(),
        sellingPrice: price,
        category: _productCategory,
        images: _productImages,
        description: _descriptionController.text.trim(),
        compareAtPrice: comparePrice,
        sku: _skuController.text.trim(),
        stockQuantity: stock,
        isAvailable: _isAvailable,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _finishAndGoToDashboard();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add First Product'),
        actions: [
          TextButton(
            onPressed: _finishAndGoToDashboard,
            child: const Text('Skip', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add your first item',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add a product now so your store is ready to receive orders.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),

                // Image upload grid
                const Text('Product Photos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._productImages.map((img) {
                        return Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                            image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickAndUploadImage,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                          ),
                          child: _isUploadingImage
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 26, color: AppTheme.textMuted),
                                    SizedBox(height: 4),
                                    Text('Add Photo', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Product Name
                _buildFieldLabel('Product Name'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(hintText: 'e.g. Vintage Denim Jacket, Iced Latte'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter product title';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Prices
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Price (${widget.store.currency})'),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration(hintText: '0.00'),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter price';
                              if (double.tryParse(val.trim()) == null) return 'Invalid price';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Compare at Price'),
                          TextFormField(
                            controller: _comparePriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration(hintText: 'Original price (opt)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Stock & SKU
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Stock Quantity'),
                          TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(hintText: '10'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('SKU / Code'),
                          TextFormField(
                            controller: _skuController,
                            decoration: _inputDecoration(hintText: 'e.g. VDJ-01'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Description
                _buildFieldLabel('Product Description'),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _inputDecoration(hintText: 'Key features, materials, sizes, flavors...'),
                ),
                const SizedBox(height: 18),

                // Available for sale switch
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SwitchListTile.adaptive(
                    title: const Text('Available for Purchase', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Item will immediately appear in your online catalog', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    value: _isAvailable,
                    activeColor: AppTheme.brandBlack,
                    onChanged: (val) => setState(() => _isAvailable = val),
                  ),
                ),
                const SizedBox(height: 36),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSaveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandBlack,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Product & Open Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _finishAndGoToDashboard,
                    child: const Text('I will add products later', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
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

