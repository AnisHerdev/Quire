import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/drive_service.dart';

final driveServiceProvider = Provider<DriveService>((ref) {
  return DriveService();
});
