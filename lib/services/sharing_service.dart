import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

final sharingServiceProvider = Provider<SharingService>((ref) {
  return SharingService();
});

class SharingService {
  void init(Function(List<SharedMediaFile>) onFilesReceived) {
    // 1. For sharing or opening media while the app is in memory
    ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        onFilesReceived(value);
      }
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // 2. For sharing or opening media when the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        onFilesReceived(value);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }
}
