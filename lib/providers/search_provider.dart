import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'drive_provider.dart';

class SearchState {
  final String query;
  final bool isSearchingCloud;
  final List<String> cloudMatchDriveIds;

  const SearchState({
    this.query = '',
    this.isSearchingCloud = false,
    this.cloudMatchDriveIds = const [],
  });

  SearchState copyWith({
    String? query,
    bool? isSearchingCloud,
    List<String>? cloudMatchDriveIds,
  }) {
    return SearchState(
      query: query ?? this.query,
      isSearchingCloud: isSearchingCloud ?? this.isSearchingCloud,
      cloudMatchDriveIds: cloudMatchDriveIds ?? this.cloudMatchDriveIds,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounceTimer;

  @override
  SearchState build() {
    return const SearchState();
  }

  void setQuery(String newQuery) {
    if (state.query == newQuery) return;

    state = state.copyWith(
      query: newQuery,
      isSearchingCloud: newQuery.isNotEmpty, // Show loading while debouncing
    );

    _debounceTimer?.cancel();
    
    if (newQuery.isEmpty) {
      state = state.copyWith(cloudMatchDriveIds: [], isSearchingCloud: false);
      return;
    }

    // Wait 500ms before hitting the Drive API to prevent spam
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final driveService = ref.read(driveServiceProvider);
      
      // If we are not authenticated, we can't search drive content
      if (!driveService.isReady) {
        state = state.copyWith(isSearchingCloud: false);
        return;
      }

      final matchedIds = await driveService.searchFilesContent(newQuery);
      
      // Ensure we haven't changed the query since the request started
      if (state.query == newQuery) {
        state = state.copyWith(
          cloudMatchDriveIds: matchedIds,
          isSearchingCloud: false,
        );
      }
    });
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const SearchState();
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
