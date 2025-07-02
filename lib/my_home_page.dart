
import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'anchor_info.dart';
import 'anchor_selection_grid.dart';
import 'arrow_key_handler.dart';
import 'bottom_panel.dart';
import 'files_indexer_text.dart';
import 'image_controller.dart';
import 'image_index_controller.dart';
import 'image_precache_service.dart';
import 'image_viewer_scaffold.dart';
import 'top_application_bar.dart';
import 'types.dart';
import 'zoom_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'constants.dart';
import 'file_utils.dart';

class MyHomePage extends StatefulWidget {

  const MyHomePage({super.key, required this.initialFilePath});

  final String initialFilePath;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>  with WindowListener {

  late ImageIndexController _imageIndexController;
  late ImagePrecacheService _imagePrecacheService;
  late ArrowKeyHandler _arrowKeyHandler;
  final GlobalKey _imageControllerKey = GlobalKey();
  final ZoomController _zoomController = ZoomController.default1();
  final ValueNotifier<ImageControlMode> _imageControlMode =
      ValueNotifier<ImageControlMode>(ImageControlMode.limited);
  final ValueNotifier<FitMode> _fitModeNotifier = ValueNotifier(FitMode.original);
  String? _folderPath;
  List<String>? _imageFiles;
  bool _isFullScreen = false;
  bool _isMaximized = false;
  bool _showBottomPanel = false;
  bool _showTopPanel = false;
  final ValueNotifier<bool> _showAnchorSelectionGrid = ValueNotifier(false);
  final ValueNotifier<AnchorInfo?> _selectedAnchorInfo = ValueNotifier(null);
  final ValueNotifier<ImageProvider<Object>?> _activeImage = ValueNotifier<ImageProvider<Object>?>(null);
  final ValueNotifier<String> activeFileName = ValueNotifier<String>("");

  @override
  void initState() {
    super.initState();

    windowManager.addListener(this);

    _zoomController.setUsePreferredZoomAsMin(
      _imageControlMode.value == ImageControlMode.limited,
    );

    _imageIndexController = ImageIndexController(defaultFilePath: widget.initialFilePath);
    _imageIndexController.addListener(_onCurrentIndexChanged);

    _arrowKeyHandler = ArrowKeyHandler(
      getCurrentIndex: () => _imageIndexController.value!,
      setCurrentIndex: (int idx) => _imageIndexController.setCurrentIndex(idx),
      getWrappedIndex: _imageIndexController.getWrappedIndex,
    );

    final file = File(widget.initialFilePath);

    if (!file.existsSync()) {
      throw Exception('File does not exist: ${widget.initialFilePath}');
    }

    _folderPath = file.parent.path;

    FileUtils.getImageFilesInFolder(_folderPath!, supportedImageExtensions)
        .then((files) {
          setState(() {
            _imageFiles = files;
            _imageIndexController.initialize(imageFiles: files,
              initialIndex: files.indexWhere(
                (p) => FileUtils.isEqual(p, widget.initialFilePath),
              ));
            log(
              'Image files loaded: ${_imageFiles!.length}'
              'found in $_folderPath',
            );
          });
        })
        .catchError((error) {
          log('Error loading image files: $error');
        });
        
    _updateWindowName();

    windowManager.isMinimized().then(
      (value) => _isMaximized = value,
    );

    _imagePrecacheService = ImagePrecacheService(context);

    _imagePrecacheService.setImageCallback((path, image) {
      if (_imageIndexController.activeFilePath == path) {
        _activeImage.value = image;
      }
    });

    _requestActiveImage();

  }

  void _requestActiveImage() {
    _activeImage.value = null;
    _imagePrecacheService.requestImage(_imageIndexController.activeFilePath);
  }

  @override
  Widget build(BuildContext context) {
    final activeFilePath = _imageIndexController.activeFilePath;

    if (!File(activeFilePath).existsSync()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(applicationName),
        ),
        body: Center(
          child: const Text('Image file not found.'),
        ),
      );
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: _getImageViewerScaffold(activeFilePath, context),
    );
  }

  Widget _getImageViewerScaffold(String filePath, BuildContext context) {
    final file = File(filePath);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split(Platform.pathSeparator).last;

    return ImageViewerScaffold(
      colorScheme: colorScheme,
      isFullScreen: _isFullScreen,
      fileName: fileName,
      imageRenderArea: _getImageRenderArea(),
      topAppBar: _getTopApplicationBar(colorScheme),
      hiddenTopAppBar: _getHiddenTopApplicationBar(colorScheme),
      bottomPanel: _getBottomPanel(colorScheme),
      hiddenBottomPanel: _getHiddenBottomPanel(colorScheme),
      anchorSelectionGrid: _getAnchorSelectionGrid(),
    );
  }

  Widget _getImageRenderArea() {
    return Stack(
      children: [
        Center(
          child: ValueListenableBuilder(
            valueListenable: _activeImage,
            builder: (context, value, child) {
              if (value == null) {
                return SizedBox.shrink();
              }

              if (!_imagePrecacheService.isImageLoaded(_imageIndexController.activeFilePath)) {
                log('_imageIndexController.activeFilePath: ${_imageIndexController.activeFilePath}');
                return SizedBox.shrink();
              }

              return ImageController(
                key: _imageControllerKey,
                image: value,
                zoomController: _zoomController,
                minScale: minZoom,
                maxScale: maxZoom,
                imageControlMode: _imageControlMode,
                fitModeNotifier: _fitModeNotifier,
                anchorInfo: _selectedAnchorInfo
                );
            }
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _imageIndexController,
          builder: (context, value, child) {
            return FilesIndexerText(
              currentIndex: value,
              totalFiles: _imageFiles != null ? _imageFiles!.length : 0,
            );
          }
        ),
      ],
    );
  }

  Widget _getTopApplicationBar(ColorScheme colorScheme) {
    return TopApplicationBar(
      colorScheme: colorScheme,
      fileName: activeFileName,
      isFullScreen: _isFullScreen,
      isMaximazed: _isMaximized,
      onMinimize: () async => await windowManager.minimize(),
      onToggleFullscreen: _toggleFullscreenMode,
      onToggleMaximize: _toggleMaximize,
      onExit: () => exit(0),
      imageControlMode: _imageControlMode,
      onToggleImageControlMode: () {
        _imageControlMode.value =
            _imageControlMode.value == ImageControlMode.limited
            ? ImageControlMode.full
            : ImageControlMode.limited;

        _zoomController.setUsePreferredZoomAsMin(
          _imageControlMode.value == ImageControlMode.limited,
        );
      },
      selectedAnchorInfo: _selectedAnchorInfo,
      onAnchorSelectionButton: () {
        // Removing anchor if it's active, if not, showing anchor selection grid
        if (_selectedAnchorInfo.value != null) {
          _selectedAnchorInfo.value = null;
        } else {
          _showAnchorSelectionGrid.value = !_showAnchorSelectionGrid.value;
        }
      },
    );
  }

  Widget _getHiddenTopApplicationBar(ColorScheme colorScheme) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showTopPanel = true),
      onExit: (_) => setState(() => _showTopPanel = false),
      child: AnimatedOpacity(
        opacity: _showTopPanel ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 100),
        child: _getTopApplicationBar(colorScheme),
      ),
    );
  }

  Widget _getBottomPanel(ColorScheme colorScheme) {
    return BottomPanel(
      zoomController: _zoomController,
      colorScheme: colorScheme,
      fitMode: _fitModeNotifier,
      onToggleFitMode: () => _fitModeNotifier.value = _fitModeNotifier.value == FitMode.original
          ? FitMode.stretch
          : FitMode.original,
    );
  }

  Widget _getHiddenBottomPanel(ColorScheme colorScheme) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showBottomPanel = true),
      onExit: (_) => setState(() => _showBottomPanel = false),
      child: AnimatedOpacity(
        opacity: _showBottomPanel ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 100),
        child: _getBottomPanel(colorScheme),
      ),
    );
  }

  AnchorSelectionGrid _getAnchorSelectionGrid() {
    return AnchorSelectionGrid(
      isVisible: _showAnchorSelectionGrid,
      onAnchorSelected: (selectedAnchorInfo) {
        _showAnchorSelectionGrid.value = false;
        _selectedAnchorInfo.value = selectedAnchorInfo;
      },
    );
  }

  void _onKeyEvent(KeyEvent event) async {
    if (event is KeyDownEvent) {
      _handleFullscreenModeToggleKey(event);
      _handleArrowKeyDownEvent(event);
    } else if (event is KeyRepeatEvent) {
      _handleArrowKeyHoldEvent(event);
    }
  }

  void _handleFullscreenModeToggleKey(KeyDownEvent event) async {
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFullscreenMode();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _exitFromFullscreenMode();
    }
  }

  void _toggleFullscreenMode() async {
    bool isFullScreen = await windowManager.isFullScreen();
    _setFullscreenMode(!isFullScreen);
  }

  void _exitFromFullscreenMode() async {
    bool isFullScreen = await windowManager.isFullScreen();
    if (!isFullScreen) {
      return;
    }
    _setFullscreenMode(false);
  }

  void _setFullscreenMode(bool active) async {
    await windowManager.setFullScreen(active);

    _isFullScreen = active;
    //PaintingBinding.instance.imageCache.clear();

    setState(() {});
  }

  void _toggleMaximize() async {
    bool isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
  
  void _handleArrowKeyDownEvent(KeyDownEvent event) {
    if (!_isDataPrepared()) {
      return;
    }
    _arrowKeyHandler.handleArrowKey(event.logicalKey);
  }

  bool _isDataPrepared() {
    return _imageFiles != null && _imageFiles!.isNotEmpty && _imageIndexController.value != null;
  }
  
  void _handleArrowKeyHoldEvent(KeyRepeatEvent event) async {
    if (!_isDataPrepared()) {
      return;
    }
    _arrowKeyHandler.handleArrowKeyHoldEvent(event);
  }

  void _onCurrentIndexChanged() {
    
    _requestActiveImage();

    _imagePrecacheService.onCurrentIndexChanged(
      imageFiles: _imageFiles,
      currentIndex: _imageIndexController.value,
      lastOffset: _arrowKeyHandler.getLastOffset(),
    );

    _updateWindowName();
  }

  void _updateWindowName() async {

    var fileName = FileUtils.getFileName(_imageIndexController.activeFilePath);

    activeFileName.value = fileName;

    await windowManager.setTitle(fileName);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void onWindowMaximize() {
    _isMaximized = true;
    setState(() {});
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized = false;
    setState(() {});
  }

  @override
  void onWindowMove() {
    if (_isMaximized) {
      _isMaximized = false;
      setState(() {});
    }
  }
  
  @override
  void dispose() {
    _zoomController.dispose();
    _imageControlMode.dispose();
    _imageIndexController.dispose();
    _fitModeNotifier.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }
}
