library signature;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:image/image.dart' as imglib;

class PdfToImage {
  Future<Map> convert(String url, int pageNumber) async {
    final ByteData bytes = await NetworkAssetBundle(Uri.parse(url)).load(url);
    final Uint8List list = bytes.buffer.asUint8List();
    List<imglib.Image> _images = [];
    final doc = await PdfDocument.openData(list);

    var page = await doc.getPage(pageNumber);
    var totalPage = doc.pageCount;
    var imgPDF = await page.render();
    var img = await imgPDF.createImageDetached();
    dynamic imgBytes = await img.toByteData(format: ImageByteFormat.png);
    dynamic libImage = imglib.decodeImage(
      imgBytes.buffer.asUint8List(
        imgBytes.offsetInBytes,
        imgBytes.lengthInBytes,
      ),
    );

    _images.add(libImage);

    var height = libImage.height;
    var width = libImage.width;

    final mergedImage = imglib.Image(width, height);
    for (var element in _images) {
      imglib.copyInto(
        mergedImage,
        element,
        dstX: 0,
        dstY: 0,
        blend: false,
      );
    }

    String nameWithExtentions = url.split('/').last;
    String nameWithoutExtentions = nameWithExtentions.split('.').first;
    final String fileName = nameWithoutExtentions + '$pageNumber' + '.jpg';

    final documentDirectory = await getExternalStorageDirectory();
    File imgFile = File('${documentDirectory!.path}/' + fileName);
    File(imgFile.path).writeAsBytesSync(imglib.encodeJpg(mergedImage));

    return {
      'height': height.toDouble(),
      'width': width.toDouble(),
      'image': imgFile,
      'total_page': totalPage,
    };
  }
}
