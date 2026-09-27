import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider<Object> selectedImageProvider(String path) =>
    FileImage(File(path));
