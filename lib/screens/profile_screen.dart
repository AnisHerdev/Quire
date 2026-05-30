import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/card_size_provider.dart';
import '../providers/drive_provider.dart';
import '../services/cache_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _storageQuota = 'Loading...';
  String _cacheSize = 'Loading...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final driveService = ref.read(driveServiceProvider);
    final cacheService = ref.read(cacheServiceProvider);
    
    if (driveService.isReady) {
      final quota = await driveService.getStorageQuota();
      if (mounted) setState(() => _storageQuota = quota);
    } else {
      if (mounted) setState(() => _storageQuota = 'Offline');
    }
    
    final cacheSize = await cacheService.getCacheSizeFormatted();
    if (mounted) setState(() => _cacheSize = cacheSize);
  }

  void _showClearCacheDialog() {
    final theme = Theme.of(context);
    int keepCount = 10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text('Clear Local Cache', style: theme.textTheme.headlineSmall),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How many recently accessed files would you like to keep downloaded?', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Keep: $keepCount', style: theme.textTheme.labelLarge),
                    Expanded(
                      child: Slider(
                        value: keepCount.toDouble(),
                        min: 0,
                        max: 50,
                        divisions: 10,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (val) {
                          setStateDialog(() => keepCount = val.toInt());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Any deleted files will simply re-download from Drive when you open them next.', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface)),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(cacheServiceProvider).clearCacheExceptRecent(keepCount);
                  _loadStats();
                },
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
                child: const Text('Clear'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface, // changed from deprecated background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: textTheme.headlineMedium?.copyWith(color: colorScheme.onSurface)), // changed from deprecated onBackground
              const SizedBox(height: 24),
              
              // 1. Compact Profile Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.surfaceVariant), // Note: if using M3, might be surfaceContainerHighest
                  boxShadow: [
                    BoxShadow(color: colorScheme.primaryContainer.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    if (user?.photoUrl.isNotEmpty == true)
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: NetworkImage(user!.photoUrl),
                        backgroundColor: colorScheme.surfaceContainer,
                      )
                    else
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: colorScheme.surfaceContainer,
                        child: Icon(Icons.person, size: 36, color: colorScheme.outline),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.displayName ?? 'Scholar', style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)), // changed from onBackground
                          const SizedBox(height: 2),
                          Text(user?.email ?? 'Unknown Email', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school, size: 14, color: colorScheme.onPrimaryContainer),
                                const SizedBox(width: 6),
                                Text('Scholar', style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimaryContainer)),
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
              
              // 2. Preferences
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
                      trailing: Switch(
                        value: themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark),
                        onChanged: (val) {
                          ref.read(themeProvider.notifier).toggleTheme(context);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.grid_view, color: colorScheme.onSurfaceVariant, size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Card Size', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface)),
                                const SizedBox(height: 4),
                                Text('Adjust grid card dimensions', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SegmentedButton<CardSize>(
                            segments: const [
                              ButtonSegment(value: CardSize.small, label: Text('S', style: TextStyle(fontSize: 12))),
                              ButtonSegment(value: CardSize.medium, label: Text('M', style: TextStyle(fontSize: 12))),
                              ButtonSegment(value: CardSize.large, label: Text('L', style: TextStyle(fontSize: 12))),
                            ],
                            selected: {ref.watch(cardSizeProvider)},
                            onSelectionChanged: (selected) {
                              ref.read(cardSizeProvider.notifier).setSize(selected.first);
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _buildSettingsTile(
                      context,
                      icon: Icons.cleaning_services,
                      title: 'Clear Cache',
                      subtitle: 'Free up local space ($_cacheSize)',
                      onTap: _showClearCacheDialog,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // 3. Storage Connection
              Text('STORAGE', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
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
                        Text('Google Drive', style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface)), // changed from onBackground
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
                                Text('Usage', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text(_storageQuota, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)), // changed from onBackground
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sync, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Active Sync Path', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text('My Drive › Quire-Notes', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)), // changed from onBackground
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
              
              // 4. Sign out and Version
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(authProvider.notifier).signOut();
                    },
                    icon: Icon(Icons.logout, color: colorScheme.error),
                    label: Text('Sign Out', style: textTheme.labelLarge?.copyWith(color: colorScheme.error)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  Text('v1.0.0', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required String subtitle, Widget? trailing, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: colorScheme.surfaceContainer, shape: BoxShape.circle),
        child: Icon(icon, color: colorScheme.onSurfaceVariant),
      ),
      title: Text(title, style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurface)), // changed from onBackground
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 14)),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      onTap: trailing is Switch ? null : (onTap ?? () {}),
    );
  }
}
