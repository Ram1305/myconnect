import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
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

  // Initialize bitsdojo window
  doWhenWindowReady(() {
    final initialSize = Size(1280, 800);
    appWindow.size = initialSize;
    appWindow.minSize = Size(800, 600);
    appWindow.alignment = Alignment.center;
    appWindow.title = 'My Connect';
    appWindow.show();
  });
}

bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
