import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../providers/database_provider.dart';
import '../providers/drive_provider.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  final String fileId;
  const PdfViewerScreen({super.key, required this.fileId});

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();
  
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;
  
  bool _isSearchMode = false;
  bool _isDarkMode = false;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController.addListener(() {
      if (mounted) {
        setState(() {
          _currentZoom = _pdfViewerController.zoomLevel;
        });
      }
    });
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      final driveService = ref.read(driveServiceProvider);
      final database = ref.read(databaseProvider);
      final file = database.files[widget.fileId];
      if (file == null) throw Exception('File not found in database');
      
      final bytes = await driveService.getPdfBytes(widget.fileId, file.driveId);
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    
    final database = ref.read(databaseProvider);
    final file = database.files[widget.fileId];
    final fileName = file?.name ?? 'Document.pdf';

    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/pdf_cache');
      final localFile = File('${cacheDir.path}/${widget.fileId}.pdf');
      
      if (await localFile.exists()) {
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(localFile.path)], subject: fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share file: $e')),
        );
      }
    }
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      _searchResult.removeListener(_onSearchChanged);
      _searchResult.clear();
      setState(() {});
      return;
    }
    
    // Clear previous listener
    _searchResult.removeListener(_onSearchChanged);
    
    _searchResult = _pdfViewerController.searchText(query);
    _searchResult.addListener(_onSearchChanged);
    setState(() {});
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _zoomIn() {
    _pdfViewerController.zoomLevel = _currentZoom + 0.5;
  }

  void _zoomOut() {
    _pdfViewerController.zoomLevel = (_currentZoom - 0.5).clamp(1.0, 5.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final database = ref.watch(databaseProvider);
    final file = database.files[widget.fileId];
    final fileName = file?.name ?? 'Unknown File';

    // Matrix to invert colors for dark mode PDF rendering
    const colorMatrix = <double>[
      -1.0, 0.0, 0.0, 0.0, 255.0,
      0.0, -1.0, 0.0, 0.0, 255.0,
      0.0, 0.0, -1.0, 0.0, 255.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(fileName, style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_pdfBytes != null)
              Text('PDF Document', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.ios_share, color: colorScheme.onSurfaceVariant), onPressed: _sharePdf),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onSelected: (value) {
              if (value == 'dark_mode') {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dark_mode',
                child: Row(
                  children: [
                    Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
                    const SizedBox(width: 12),
                    Text(_isDarkMode ? 'Light Mode' : 'Dark Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bookmark',
                child: Row(
                  children: [
                    Icon(Icons.bookmark_border, size: 20),
                    SizedBox(width: 12),
                    Text('Bookmark File'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Failed to load PDF', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else if (_pdfBytes != null)
            ColorFiltered(
              colorFilter: _isDarkMode
                  ? const ColorFilter.matrix(colorMatrix)
                  : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
              child: SfPdfViewer.memory(
                _pdfBytes!,
                controller: _pdfViewerController,
                canShowScrollHead: false,
                canShowScrollStatus: false,
                pageSpacing: 8,
              ),
            ),
          
          // Floating Bottom Toolbar
          if (_pdfBytes != null)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: colorScheme.primaryContainer.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 8)),
                    ],
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: _isSearchMode ? _buildSearchBar(context) : _buildDefaultToolbar(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultToolbar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: _zoomOut, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('${(_currentZoom * 100).toInt()}%', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _zoomIn, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(width: 1, height: 24, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.search, size: 22), 
          color: colorScheme.onSurfaceVariant,
          onPressed: () {
            setState(() {
              _isSearchMode = true;
            });
          }, 
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onSubmitted: _performSearch,
            onChanged: (val) {
              if (val.isEmpty) {
                _searchResult.clear();
                setState(() {});
              }
            },
          ),
        ),
        if (_searchResult.hasResult) ...[
          Text(
            '${_searchResult.currentInstanceIndex} of ${_searchResult.totalInstanceCount}',
            style: textTheme.labelSmall?.copyWith(color: colorScheme.primary),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () {
              _searchResult.previousInstance();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () {
              _searchResult.nextInstance();
              setState(() {});
            },
          ),
        ],
        Container(width: 1, height: 24, color: colorScheme.outlineVariant.withValues(alpha: 0.5), margin: const EdgeInsets.symmetric(horizontal: 4)),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _searchResult.removeListener(_onSearchChanged);
            _searchResult.clear();
            _searchController.clear();
            setState(() {
              _isSearchMode = false;
            });
          },
        ),
      ],
    );
  }
}
