import 'package:flutter/foundation.dart';

/// Centralized domain configuration for FlowTake.
///
/// Designed so that the platform base domain can be configured through a single
/// setting (or environment variable / Remote Config) without modifying store records
/// or registration logic.
enum DomainMode {
  development,
  production,
}

class DomainConfig {
  DomainConfig._();

  /// Central base domain (e.g. 'localhost' in dev, or 'yourdomain.com' in prod)
  /// Can be overridden via `--dart-define=PLATFORM_BASE_DOMAIN=...`
  static const String _envBaseDomain = String.fromEnvironment(
    'PLATFORM_BASE_DOMAIN',
    defaultValue: 'localhost',
  );

  /// Operational domain mode ('development' or 'production')
  /// Can be overridden via `--dart-define=DOMAIN_MODE=...`
  static const String _envDomainMode = String.fromEnvironment(
    'DOMAIN_MODE',
    defaultValue: 'development',
  );

  /// Reserved store slug for local testing / demo showcase
  static const String defaultStoreSlug = 'demo';

  /// Reserved subdomains / system paths that cannot be claimed by stores
  static const Set<String> reservedSlugs = {
    'admin',
    'api',
    'login',
    'dashboard',
    'support',
    'www',
    'app',
    'auth',
    'portal',
    'root',
    'static',
    'assets',
    'mail',
    'billing',
    'help',
    'docs',
  };

  /// Runtime configurable platform base domain (defaults to environment or 'localhost')
  static String platformBaseDomain = _envBaseDomain;

  /// Runtime configurable domain mode
  static DomainMode domainMode = _envDomainMode == 'production'
      ? DomainMode.production
      : DomainMode.development;

  /// Check if running in development mode
  static bool get isDevelopment => domainMode == DomainMode.development;

  /// Check if the base domain is localhost or development placeholder
  static bool get isLocalhost =>
      platformBaseDomain.toLowerCase() == 'localhost' ||
      platformBaseDomain.toLowerCase().endsWith('.localhost') ||
      isDevelopment;

  /// Build the full URL for a store slug
  ///
  /// Examples:
  /// - development: https://fresh-mart.localhost
  /// - production:  https://fresh-mart.myplatform.com
  static String buildStoreUrl(String storeSlug) {
    final cleanSlug = storeSlug.trim().toLowerCase();
    final scheme = isLocalhost ? 'http' : 'https';
    final port = isLocalhost && kIsWeb ? ':3000' : '';
    return '$scheme://$cleanSlug.$platformBaseDomain$port';
  }

  /// Resolve incoming hostname to a store slug (for web wildcard hosting)
  ///
  /// Example:
  /// `demo.localhost` -> 'demo'
  /// `faizulstore.myplatform.com` -> 'faizulstore'
  /// Returns null if host matches the apex domain or is reserved.
  static String? resolveHostToSlug(String host) {
    final cleanHost = host.trim().toLowerCase().split(':')[0]; // strip port
    final cleanBase = platformBaseDomain.trim().toLowerCase();

    // Check if host matches base domain directly (apex platform domain)
    if (cleanHost == cleanBase || cleanHost == 'www.$cleanBase') {
      return null;
    }

    if (cleanHost.endsWith('.$cleanBase')) {
      final slug = cleanHost.substring(0, cleanHost.length - (cleanBase.length + 1));
      // Nested subdomains like a.b.domain -> only take first part or reject
      final parts = slug.split('.');
      if (parts.length == 1) {
        return parts.first;
      }
    }

    return null;
  }

  /// Clean & validate store username / subdomain slug
  /// Rules:
  /// - Lowercase letters, numbers, and hyphens only
  /// - No spaces
  /// - No leading or trailing hyphens
  /// - No consecutive hyphens
  /// - Min 3, Max 40 characters
  /// - Not in reservedSlugs
  static SlugValidationResult validateSlug(String rawInput) {
    final slug = rawInput.trim().toLowerCase();

    if (slug.isEmpty) {
      return const SlugValidationResult(
        isValid: false,
        error: 'Store username cannot be empty.',
      );
    }

    if (slug.length < 3) {
      return const SlugValidationResult(
        isValid: false,
        error: 'Must be at least 3 characters long.',
      );
    }

    if (slug.length > 40) {
      return const SlugValidationResult(
        isValid: false,
        error: 'Must be at most 40 characters long.',
      );
    }

    if (slug.startsWith('-') || slug.endsWith('-')) {
      return const SlugValidationResult(
        isValid: false,
        error: 'Cannot start or end with a hyphen.',
      );
    }

    if (slug.contains('--')) {
      return const SlugValidationResult(
        isValid: false,
        error: 'Cannot contain consecutive hyphens.',
      );
    }

    final validCharactersRegex = RegExp(r'^[a-z0-9-]+$');
    if (!validCharactersRegex.hasMatch(slug)) {
      return const SlugValidationResult(
        isValid: false,
        error: 'Lowercase letters, numbers and hyphens only.',
      );
    }

    if (reservedSlugs.contains(slug)) {
      return SlugValidationResult(
        isValid: false,
        error: '"$slug" is a reserved platform name. Please choose another.',
      );
    }

    return SlugValidationResult(isValid: true, sanitizedSlug: slug);
  }

  /// Automatically generate a clean slug from a store name
  static String generateSlug(String storeName) {
    var slug = storeName.trim().toLowerCase();

    // Replace spaces and underscores with hyphens
    slug = slug.replaceAll(RegExp(r'[\s_]+'), '-');

    // Remove any character that is not a-z, 0-9, or hyphen
    slug = slug.replaceAll(RegExp(r'[^a-z0-9-]'), '');

    // Collapse multiple hyphens
    slug = slug.replaceAll(RegExp(r'-+'), '-');

    // Trim leading and trailing hyphens
    if (slug.startsWith('-')) slug = slug.substring(1);
    if (slug.endsWith('-')) slug = slug.substring(0, slug.length - 1);

    return slug;
  }
}

class SlugValidationResult {
  final bool isValid;
  final String? error;
  final String? sanitizedSlug;

  const SlugValidationResult({
    required this.isValid,
    this.error,
    this.sanitizedSlug,
  });
}

