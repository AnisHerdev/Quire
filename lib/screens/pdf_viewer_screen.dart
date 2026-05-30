import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';

import '../providers/database_provider.dart';
import '../providers/drive_provider.dart';

import '../providers/drive_provider.dart';

class _GlideScrollPhysics extends BouncingScrollPhysics {
  const _GlideScrollPhysics({super.parent});

  @override
  _GlideScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _GlideScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final tolerance = this.toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return BouncingScrollSimulation(
        spring: spring,
        position: position.pixels,
        velocity: velocity * 3.0, // Boost velocity for even longer glide
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
      );
    }
    return null;
  }
}

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

  bool _isFullscreen = false;
  bool _showToolbar = true;
  Timer? _toolbarHideTimer;

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
    _startToolbarHideTimer();
  }

  @override
  void dispose() {
    _toolbarHideTimer?.cancel();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _pdfViewerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startToolbarHideTimer() {
    _toolbarHideTimer?.cancel();
    _toolbarHideTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted && !_isSearchMode) {
        setState(() {
          _showToolbar = false;
        });
      }
    });
  }

  void _onPdfInteraction() {
    if (!_showToolbar) {
      setState(() {
        _showToolbar = true;
      });
    }
    _startToolbarHideTimer();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _loadPdf() async {
    try {
      final driveService = ref.read(driveServiceProvider);
      final database = ref.read(databaseProvider);
      final file = database.files[widget.fileId];
      if (file == null) throw Exception('File not found in database');
      
      final bytes = await driveService.getPdfBytes(widget.fileId, file.driveId, mimeType: file.mimeType);
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
        // Copy to temp directory with the actual custom name so OS shares it properly
        final tempDir = await getTemporaryDirectory();
        
        // Sanitize filename to avoid path issues
        var safeFileName = fileName.replaceAll(RegExp(r'[\\/]'), '_');
        if (!safeFileName.toLowerCase().endsWith('.pdf')) {
          safeFileName = '$safeFileName.pdf';
        }
        
        final tempFile = File('${tempDir.path}/$safeFileName');
        await localFile.copy(tempFile.path);

        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(tempFile.path)], subject: safeFileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share file: $e')),
        );
      }
    }
  }

  Future<void> _openExternally() async {
    if (_pdfBytes == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/pdf_cache');
      final localFile = File('${cacheDir.path}/${widget.fileId}.pdf');
      if (await localFile.exists()) {
        await OpenFilex.open(localFile.path, type: 'application/pdf');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
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

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullscreen) {
          _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: _isFullscreen ? null : AppBar(
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
          IconButton(
            icon: Icon(Icons.search, color: colorScheme.onSurfaceVariant), 
            onPressed: () {
              setState(() {
                _isSearchMode = true;
              });
            },
          ),
          IconButton(icon: Icon(Icons.fullscreen, color: colorScheme.onSurfaceVariant), onPressed: _toggleFullscreen),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onSelected: (value) {
              if (value == 'dark_mode') {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              } else if (value == 'share') {
                _sharePdf();
              } else if (value == 'open_external') {
                _openExternally();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'open_external',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 20),
                    SizedBox(width: 12),
                    Text('Open Externally'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.ios_share, size: 20),
                    SizedBox(width: 12),
                    Text('Share PDF'),
                  ],
                ),
              ),
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
            Listener(
              onPointerDown: (_) => _onPdfInteraction(),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  physics: const _GlideScrollPhysics(),
                ),
                child: ColorFiltered(
                  colorFilter: _isDarkMode
                      ? const ColorFilter.matrix(colorMatrix)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: SfPdfViewer.memory(
                    _pdfBytes!,
                    controller: _pdfViewerController,
                    canShowScrollHead: _showToolbar,
                    canShowScrollStatus: _showToolbar,
                    pageSpacing: 8,
                  ),
                ),
              ),
            ),
          
          // Fullscreen floating exit button
          if (_isFullscreen)
            Positioned(
              top: 48,
              left: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showToolbar ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showToolbar,
                  child: IconButton.filled(
                    icon: const Icon(Icons.fullscreen_exit),
                    onPressed: _toggleFullscreen,
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

          // Search Pill Toolbar
          if (_pdfBytes != null && !_isFullscreen)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              bottom: _isSearchMode ? 32 : -100,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isSearchMode ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isSearchMode,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.symmetric(
                        horizontal: _isFullscreen ? 8 : 16, 
                        vertical: _isFullscreen ? 4 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: colorScheme.primaryContainer.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 8)),
                        ],
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: _isSearchMode ? _buildSearchBar(context) : const SizedBox(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ));
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
            style: textTheme.bodyMedium?.copyWith(fontSize: _isFullscreen ? 13 : null),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.outline, fontSize: _isFullscreen ? 13 : null),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: _isFullscreen ? 4 : 8),
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
            style: textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontSize: _isFullscreen ? 11 : null),
          ),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_up, size: _isFullscreen ? 18 : 24),
            padding: _isFullscreen ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: _isFullscreen ? const BoxConstraints() : null,
            onPressed: () {
              _searchResult.previousInstance();
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down, size: _isFullscreen ? 18 : 24),
            padding: _isFullscreen ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: _isFullscreen ? const BoxConstraints() : null,
            onPressed: () {
              _searchResult.nextInstance();
              setState(() {});
            },
          ),
        ],
        Container(width: 1, height: _isFullscreen ? 16 : 24, color: colorScheme.outlineVariant.withValues(alpha: 0.5), margin: const EdgeInsets.symmetric(horizontal: 4)),
        IconButton(
          icon: Icon(Icons.close, size: _isFullscreen ? 18 : 24),
          padding: _isFullscreen ? EdgeInsets.zero : const EdgeInsets.all(8),
          constraints: _isFullscreen ? const BoxConstraints() : null,
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
