import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  final AuthService authService;

  const HomeScreen({
    super.key,
    required this.user,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'Sign out?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppTheme.textSecondary)),
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
                await authService.signOut();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.brandBlack,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? Text(
                              (user.displayName?.isNotEmpty == true
                                      ? user.displayName![0]
                                      : (user.email?.isNotEmpty == true
                                          ? user.email![0]
                                          : 'U'))
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? 'Store Owner',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? user.uid,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Store Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),

              // Overview Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Sales',
                      value: '\$0.00',
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active Orders',
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
                      title: 'Products',
                      value: '0',
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


            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppTheme.textSecondary),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
