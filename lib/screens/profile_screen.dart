import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: textTheme.headlineMedium?.copyWith(color: colorScheme.onBackground)),
              const SizedBox(height: 24),
              
              // Profile Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.surfaceVariant),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primaryContainer.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: colorScheme.surfaceContainer,
                      child: Icon(Icons.person, size: 48, color: colorScheme.outline),
                    ),
                    const SizedBox(height: 16),
                    Text('Rahul Sharma', style: textTheme.headlineMedium?.copyWith(color: colorScheme.onBackground)),
                    const SizedBox(height: 4),
                    Text('rahul.s@college.edu', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school, size: 16, color: colorScheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text('Scholar', style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimaryContainer)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Drive Connection Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.surfaceVariant),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primaryContainer.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_shared, color: colorScheme.secondary, size: 28),
                        const SizedBox(width: 12),
                        Text('Storage Connection', style: textTheme.labelLarge?.copyWith(color: colorScheme.onBackground)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Active Sync Path', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text('Google Drive › Quire-Notes', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Settings List
              Text('PREFERENCES', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.surfaceVariant),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.dark_mode,
                      title: 'Dark Mode',
                      subtitle: 'Adjust interface appearance',
                      trailing: Switch(value: false, onChanged: (val) {}),
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.storage,
                      title: 'Storage',
                      subtitle: '2.4 GB used of 15 GB',
                      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.key,
                      title: 'Drive Permissions',
                      subtitle: 'Manage access to Quire-Notes',
                      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.cleaning_services,
                      title: 'Clear Cache',
                      subtitle: 'Free up local space (142 MB)',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.logout, color: colorScheme.error),
                    label: Text('Sign Out', style: textTheme.labelLarge?.copyWith(color: colorScheme.error)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  Text('Version 1.0.2', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required String subtitle, Widget? trailing}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: colorScheme.surfaceContainer, shape: BoxShape.circle),
        child: Icon(icon, color: colorScheme.onSurfaceVariant),
      ),
      title: Text(title, style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onBackground)),
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 14)),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      onTap: trailing is Switch ? null : () {},
    );
  }
}
