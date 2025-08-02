import 'package:flutter/material.dart';

import '../widget/google_file_picker_widget.dart';

/// Demo screen that showcases the mobile-compatible Google Drive file picker
class DriveFilePickerDemo extends StatelessWidget {
  const DriveFilePickerDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const GoogleDriveFilePickerWidget();
  }
}