import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initDesktop() async {
  // Initialize window manager
  await windowManager.ensureInitialized();
  
  // Set window options
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(800, 600),
    center: true,
    title: 'My Connect',
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
