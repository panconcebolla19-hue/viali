import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PreguntaImagen extends StatelessWidget {
  final String path;
  final double height;
  const PreguntaImagen({super.key, required this.path, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return Image.asset(path, height: height, fit: BoxFit.contain);
    }
    return SvgPicture.asset(path, height: height, fit: BoxFit.contain);
  }
}
