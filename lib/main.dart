import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'my_home_page.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:developer';
import 'constants.dart';
import 'package:screen_retriever/screen_retriever.dart';

void main(List<String> args) async {

  String filePath = await _getOpenFilePath(args);

  if (filePath.isEmpty) {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  
  _hideWindowsTitleBar();

  _limitWindowSize(Size(320, 225));

  runApp(MyApp(initialFilePath: filePath));
}

Future<String> _getOpenFilePath(List<String> args) async{

  String filePath = '';
  
  if (args.isEmpty) {
    log('No file path provided. Please provide a file path as an argument.');
  } else {
    var file = File(args[0]);
    if (!file.existsSync()) {
      log('File does not exist:${args[0]}');
    } else if (!supportedImageExtensions
      .any((ext) => file.path.toLowerCase().endsWith(ext))) {
      log('Unsupported file type: ${file.path}');
    } else {
      filePath = file.path;
      log('File path provided: $filePath');
    }
  }
  
  if (kDebugMode) {
    filePath = await _getConfigFilePath();
  }

  return filePath;
}

Future<String> _getConfigFilePath() async {
  try {
    final configFile = File('config.txt');
    if (await configFile.exists()) {
      final lines = await configFile.readAsLines();
      for (var line in lines) {
        if (line.startsWith('image_path=')) {
          return line.split('=')[1].trim();
        }
      }
    }
  } catch (e) {
    return '';
  }
  return '';
}

void _limitWindowSize(Size size) {
  WindowManager.instance.ensureInitialized().then((_) async {
    await WindowManager.instance.setMinimumSize(size);
  });
}

Future<void> _hideWindowsTitleBar() async {
  await windowManager.waitUntilReadyToShow().then((_) async {

    await _centerWindowOnActiveDisplay();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.show();
  });
}

Future<void> _centerWindowOnActiveDisplay() async {
  
  final cursorScreenPoint = await screenRetriever.getCursorScreenPoint();
  final displays = await screenRetriever.getAllDisplays();
  
  // Find the screen that contains the cursor
  Display? cursorScreen;
  try {
    cursorScreen = displays.firstWhere(
      (display) {
        final position = display.visiblePosition;
        final size = display.visibleSize;
        if (position == null || size == null) {
          return false;
        }
        return cursorScreenPoint.dx >= position.dx &&
            cursorScreenPoint.dx < position.dx + size.width &&
            cursorScreenPoint.dy >= position.dy &&
            cursorScreenPoint.dy < position.dy + size.height;
      },
    );
  } catch (e) {
    cursorScreen = null;
  }
  
  //,
  if (cursorScreen != null &&
      cursorScreen.visiblePosition != null &&
      cursorScreen.visibleSize != null) {
    // Get the screen's visible bounds
    final position = cursorScreen.visiblePosition!;
    final size = cursorScreen.visibleSize!;
    // Calculate the center position for the window
    final windowSize = await windowManager.getSize();
    final double x = position.dx + (size.width - windowSize.width) / 2;
    final double y = position.dy + (size.height - windowSize.height) / 2;
  
    // Set the window position
    await windowManager.setPosition(Offset(x, y));
  } else {
    // Fallback: Center on the primary screen
    await windowManager.center();
  }
}


class MyApp extends StatelessWidget {

  final String initialFilePath;

  const MyApp({super.key, required this.initialFilePath});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp( 
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey, brightness: Brightness.dark),
      ),
      home: MyHomePage(initialFilePath: initialFilePath),
    );
  }
}
