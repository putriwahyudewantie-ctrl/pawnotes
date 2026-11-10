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

  bool _isInitializing = false;
  bool _isTakingPicture = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing || !mounted) return;

    _isInitializing = true;

    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final oldController = _controller;
      _controller = null;

      if (oldController != null) {
        await oldController.dispose();
      }

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang terdeteksi.');
      }

      // Utamakan kamera depan jika tersedia.
      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final newController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = newController;

      await newController.initialize();

      if (!mounted) {
        await newController.dispose();
        return;
      }

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

  Future<void> _takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
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
                style: const TextStyle(color: Colors.white),
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

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Menghubungkan kamera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final cameraReady =
        controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ambil Foto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildCameraPreview(),
                  ),
                  if (cameraReady)
                    const Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Posisikan objek yang ingin difoto',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Tombol ambil foto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Colors.black,
              child: Center(
                child: GestureDetector(
                  onTap: cameraReady && !_isTakingPicture
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
                          color: cameraReady && !_isTakingPicture
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
