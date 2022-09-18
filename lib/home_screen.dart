import 'dart:convert';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite/tflite.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<CameraDescription> _cameras;
  CameraController? _cameraController;
  bool _sheetBlur = false;
  double? maxTop;
  String? _currentPrediction;

  @override
  void initState() {
    getCameras();
    super.initState();
  }

  Future<bool> checkPermission() async {
    var status = await Permission.camera.status;

    if (status.isGranted) {
      return status.isGranted;
    }

    if (status.isDenied && await Permission.camera.shouldShowRequestRationale) {
      await showDialog(
          context: context,
          builder: (context) {
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: AlertDialog(
                title: const Text("Camera Permission Required"),
                content: const Text(
                    "Camera Permission Is Required Inorder To Detect"),
                actions: [
                  TextButton(
                      onPressed: () async {
                        status = await Permission.camera.request();
                        Navigator.of(context).pop();
                      },
                      child: const Text("Grant")),
                  TextButton(
                      onPressed: () {
                        status = PermissionStatus.denied;
                        Navigator.of(context).pop();
                      },
                      child: const Text("Deny")),
                ],
              ),
            );
          });

      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      return status.isGranted;
    }

    await Permission.camera.request();
    if (status.isDenied && await Permission.camera.shouldShowRequestRationale) {
      await showDialog(
          context: context,
          builder: (context) {
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: AlertDialog(
                title: const Text("Camera Permission Required"),
                content: const Text(
                    "Camera Permission Is Required Inorder To Detect"),
                actions: [
                  TextButton(
                      onPressed: () async {
                        status = await Permission.camera.request();
                        Navigator.of(context).pop();
                      },
                      child: const Text("Grant")),
                  TextButton(
                      onPressed: () {
                        status = PermissionStatus.denied;
                        Navigator.of(context).pop();
                      },
                      child: const Text("Deny")),
                ],
              ),
            );
          });
    }
    return status.isGranted;
  }

  Future getCameras() async {
    if (await checkPermission()) {
      _cameras = await availableCameras();
      startCamera();
    } else {
      showDialog(
          context: context,
          builder: (context) {
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: const AlertDialog(
                title: Text("Camera Permission Denied"),
                content: Text(
                    "Please Grand Camera Permission and Restart Application"),
              ),
            );
          });
    }
  }

  Future startCamera() async {
    var backCamera = _cameras
        .where((element) => element.lensDirection == CameraLensDirection.back )
        .first;
    setState(() {
      _cameraController = CameraController(backCamera, ResolutionPreset.max);
    });
    try {
      await _cameraController?.initialize();
      setState(() {});
      startDetection();
    } on CameraException catch (e) {
      showDialog(
          context: context,
          builder: (context) {
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: AlertDialog(
                title: const Text("Camera Error"),
                content: Text(e.code),
              ),
            );
          });
    }
  }

  Future startDetection() async {
    print("DETECHTION STARTED");
    await Tflite.loadModel(model: "assets/model.tflite",labels: "assets/labels.txt");

    var run = true;
    _cameraController?.startImageStream((image) async {
      if (run) {
        run = false;
        var data = image.planes.map((e) => e.bytes).toList();
        print("PROCESSING");
        var res = await Tflite.runModelOnFrame(
          bytesList: data,
          numResults: 1
        );
        print("RESULT");
        print("$res");
        if(res != null && res.isNotEmpty){
          setState(() {
            _currentPrediction = jsonEncode(res[0]);
          });
        }

        await Future.delayed(const Duration(seconds: 1));
        run = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    maxTop ??= (MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top) /
        MediaQuery.of(context).size.height;
    return Scaffold(
      body: _cameraController != null
          ? SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: CameraPreview(_cameraController!)),
                  NotificationListener<DraggableScrollableNotification>(
                    onNotification: (notification) {
                      if (maxTop == notification.extent) {
                        setState(() {
                          _sheetBlur = true;
                        });
                      } else if (notification.extent == 0.1) {
                        setState(() {
                          _sheetBlur = false;
                        });
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                        initialChildSize: 0.1,
                        minChildSize: 0.1,
                        maxChildSize: maxTop!,
                        snap: true,
                        builder: (context, scrollController) {
                          return SingleChildScrollView(
                            controller: scrollController,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: _sheetBlur ? 10 : 0,
                                  sigmaY: _sheetBlur ? 10 : 0),
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.height,
                                decoration: BoxDecoration(
                                    color: _sheetBlur
                                        ? Colors.transparent
                                        : Colors.white,
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        topRight: Radius.circular(10))),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Container(
                                        width: 50,
                                        height: 2,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text("$_currentPrediction"),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                  )
                ],
              ))
          : Container(
              color: Colors.deepPurple,
              child: const Center(
                child: Text("SET UP"),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
