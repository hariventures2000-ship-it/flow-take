# FlowTake

> A multi-store e-commerce & WhatsApp selling platform inspired by Take.app, built with Flutter and Firebase.

FlowTake enables business owners and merchants to create branded online storefronts in minutes, generate unique subdomains, showcase product catalogs, and seamlessly receive customer orders directly on WhatsApp.

---

## 🌟 Key Features

### 1. Seamless Multi-Channel Authentication
- **Google Sign-In**: One-tap sign in with native Firebase OAuth.
- **Secure Email OTP**: Single-use 6-digit cryptographic verification delivered straight to user email inbox with anti-abuse rate limits and session persistence.

### 2. Take.app-Style Store Onboarding
- **Smart Username / Subdomain Generation**: Automatically converts store names into URL-friendly slugs (e.g. `Fresh Mart` $\to$ `fresh-mart`).
- **Live URL Preview**: Real-time display of the generated storefront link with development badges.
- **Atomic Slug Availability**: Real-time checking against existing stores with strict validation preventing reserved names (`admin`, `api`, `dashboard`, `www`, etc.).
- **Localized Commerce**: Support for WhatsApp Business numbers, international country selector, and local currency preferences.

### 3. Store Customization & Branding
- **Logo & Cover Image Uploads**: Upload high-resolution banners and avatars directly to cloud storage.
- **Curated Brand Accent Colors**: Select primary palette styles.
- **Business Bio & Fulfillment Toggles**: Configure customer delivery options, store pickup preferences, and physical store address.

### 4. Product Catalog Management
- Add catalog products with multiple image uploads.
- Specify selling prices, compare-at promotional prices, inventory stock counts, SKUs, and category tags.
- Instant stock availability toggle ("In Stock" / "Sold Out").

### 5. Multi-Store Dashboard & Store Switcher
- Manage multiple distinct storefronts under a single authenticated account.
- In-app store switcher bottom sheet to jump between businesses.
- Real-time business metrics: Total Sales, Total Orders, Pending Orders, Completed Orders, Products, and Customers.
- Quick-copy link buttons to share storefront URLs directly to social media and WhatsApp.

---

## 🌐 Centralized Domain Architecture

FlowTake is architected with a **flexible, centralized domain resolver** so you never have to purchase a domain to test, and you never need to rewrite database records when you launch in production.

### Current Development Mode
```dart
PLATFORM_BASE_DOMAIN = 'localhost';
DEFAULT_STORE_SLUG  = 'demo';
DOMAIN_MODE          = 'development';
```
- Generated store URLs: `http://<store-slug>.localhost`
- Marked clearly as **Development Preview** in the UI.

### Production Wildcard Architecture
When launching on your custom domain (e.g. `myplatform.com`):
1. Point your domain DNS records:
   - Root: `@` $\to$ Your hosting server / load balancer
   - Wildcard: `*.myplatform.com` $\to$ Your hosting server
2. Provision a Wildcard SSL certificate for `*.myplatform.com`.
3. Provide the domain configuration at runtime or in `lib/services/domain_config.dart`:
   ```bash
   flutter run --dart-define=PLATFORM_BASE_DOMAIN=myplatform.com --dart-define=DOMAIN_MODE=production
   ```
4. All store links immediately resolve to `https://<store-slug>.myplatform.com` without changing any Firestore records!

---

## 🗄️ Firestore Database Architecture

```text
users/{uid}
  ├── email: String
  ├── displayName: String
  └── lastLoginAt: Timestamp

storeSlugs/{slug}                        <-- Atomic reservation preventing duplicate slugs
  ├── storeId: String
  ├── ownerId: String
  └── createdAt: Timestamp

stores/{storeId}
  ├── ownerId: String                    <-- Linked to Firebase Auth UID
  ├── storeName: String
  ├── storeSlug: String
  ├── category: String
  ├── whatsappNumber: String
  ├── country: String
  ├── currency: String
  ├── logoUrl: String?
  ├── bannerUrl: String?
  ├── description: String?
  ├── brandColor: String
  ├── pickupEnabled: Boolean
  ├── deliveryEnabled: Boolean
  ├── address: String?
  ├── onboardingCompleted: Boolean
  ├── createdAt: Timestamp
  └── updatedAt: Timestamp
       └── products/{productId}         <-- Subcollection
             ├── name: String
             ├── images: List<String>
             ├── sellingPrice: Number
             ├── compareAtPrice: Number?
             ├── stockQuantity: Number
             ├── sku: String?
             ├── category: String
             └── isAvailable: Boolean
```

---

## 📱 Tech Stack

- **Frontend**: Flutter 3.x (Dart 3.x) with Material 3
- **Authentication**: Firebase Authentication & Next.js Resend OTP Mailer API
- **Database**: Cloud Firestore
- **Storage**: Firebase Storage & local responsive fallbacks
- **State & Routing**: StreamBuilder auth listener, `SharedPreferences` session cache, and multi-store gate router

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.13.0`
- Android SDK / iOS Xcode / Chrome for Web
- Firebase project configured with `google-services.json` (Android) / `firebase_options.dart`

### Running the App
```bash
# 1. Install dependencies
flutter pub get

# 2. Run on connected mobile device or emulator
flutter run

# 3. (Optional) Run with custom domain configuration
flutter run --dart-define=PLATFORM_BASE_DOMAIN=myplatform.com --dart-define=DOMAIN_MODE=production
```

---

## 🔒 Security
- Strict Firestore security rules in `firestore.rules` protect store ownership so only the store owner can edit catalog items or modify store settings.
- Slugs are reserved atomically within transactions to prevent collision or duplicate creation.
