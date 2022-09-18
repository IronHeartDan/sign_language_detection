import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

class ImageClassification extends StatefulWidget {
  const ImageClassification({Key? key}) : super(key: key);

  @override
  State<ImageClassification> createState() => _ImageClassificationState();
}

class _ImageClassificationState extends State<ImageClassification> {
  final ImagePicker _picker = ImagePicker();
  String? _currentImage;
  String? modelResult;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future loadModel() async {
    await Tflite.loadModel(
      model: "assets/tflite/model.tflite",
      labels: "assets/tflite/labels.txt",
    );
  }

  Future detect(String path) async {
    var res = await Tflite.runModelOnImage(path: path, numResults: 1);
    print("Result->  $res");
    setState(() {
      if (res != null) modelResult = res[0]['label'].toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _currentImage == null
                  ? SvgPicture.asset("assets/images/select_image.svg")
                  : Image.file(File(_currentImage!)),
              ElevatedButton(
                  onPressed: () async {
                    var image =
                        await _picker.pickImage(source: ImageSource.gallery);
                    setState(() {
                      _currentImage = image?.path;
                    });
                    if (image != null) detect(image.path);
                  },
                  child: const Text("Select Image")),
              Text("Found : $modelResult"),
            ],
          ),
        ),
      ),
    );
  }
}
