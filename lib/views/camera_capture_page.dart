
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  bool _isInitializing = false;
  bool _isTakingPicture = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera({
    CameraDescription? selectedCamera,
  }) async {
    if (_isInitializing || !mounted) return;

    _isInitializing = true;

    setState(() {
      _errorMessage = null;
    });

    try {
      final oldController = _controller;
      _controller = null;

      if (oldController != null) {
        await oldController.dispose();
      }

      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang terdeteksi.');
      }

      // Utamakan kamera belakang.
      // Jika tidak tersedia, gunakan kamera pertama.
      final camera = selectedCamera ??
          _cameras.firstWhere(
            (camera) =>
                camera.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );

      final newController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = newController;

      await newController.initialize();

      if (!mounted) {
        await newController.dispose();
        return;
      }

      _selectedCameraIndex = _cameras.indexOf(camera);

      setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error is CameraException
              ? 'Kamera tidak dapat dibuka: ${error.description ?? error.code}'
              : 'Kamera tidak dapat dibuka: $error';
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_isInitializing ||
        _isTakingPicture ||
        _cameras.length < 2) {
      return;
    }

    final nextIndex =
        (_selectedCameraIndex + 1) % _cameras.length;

    final nextCamera = _cameras[nextIndex];

    await _initializeCamera(
      selectedCamera: nextCamera,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final controller = _controller;
      _controller = null;

      if (controller != null) {
        unawaited(controller.dispose());
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) {
        _initializeCamera();
      }
    }
  }

  // ==========================================
  // AMBIL FOTO
  // ==========================================

  Future<void> _takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture ||
        _isInitializing) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final photo = await controller.takePicture();

      if (!mounted) return;

      Navigator.of(context).pop(photo);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  Widget _buildCameraPreview() {
    final controller = _controller;

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Menghubungkan kamera...',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Menggunakan rasio asli kamera.
    // Tidak menggunakan Transform.scale agar
    // gambar tidak mengalami zoom berlebihan.

    return Center(
      child: CameraPreview(controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final cameraReady =
        controller != null &&
        controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ambil Foto',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // AREA PREVIEW KAMERA
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildCameraPreview(),
                  ),

                  // PETUNJUK DAN TOMBOL GANTI KAMERA
                  if (cameraReady)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Posisikan objek yang ingin difoto',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_cameras.length > 1)
                            IconButton(
                              onPressed:
                                  _isInitializing ||
                                          _isTakingPicture
                                      ? null
                                      : _switchCamera,
                              tooltip: 'Ganti Kamera',
                              icon: const Icon(
                                Icons.flip_camera_android,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // TOMBOL AMBIL FOTO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 24,
              ),
              color: Colors.black,
              child: Center(
                child: GestureDetector(
                  onTap: cameraReady &&
                          !_isTakingPicture &&
                          !_isInitializing
                      ? _takePicture
                      : null,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cameraReady &&
                                  !_isTakingPicture &&
                                  !_isInitializing
                              ? Colors.white
                              : Colors.grey,
                        ),
                        child: _isTakingPicture
                            ? const Padding(
                                padding: EdgeInsets.all(17),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                                size: 28,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }
}
