library signature;

import 'dart:async';

import 'package:flutter/material.dart';
import 'pdf_to_image.dart';

class Signature extends StatefulWidget {
  final double boxHeight, boxWidth;

  final StreamController<Map> stream;

  final Widget child;

  final String fileUrl;

  const Signature({
    Key? key,
    this.boxHeight = 40,
    this.boxWidth = 160,
    required this.stream,
    required this.child,
    required this.fileUrl,
  }) : super(key: key);

  @override
  _SignatureState createState() => _SignatureState();
}

class _SignatureState extends State<Signature> {
  int initPage = 1;
  int totalPage = 0;

  // Controller
  final TransformationController _transformationController = TransformationController();

  // Utilities
  final PdfToImage _convertPdfToImage = PdfToImage();

  @override
  void initState() {
    _transformationController.value = Matrix4.identity() * 0.01;
    super.initState();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<Map> _convertPdf(String url, page) {
    return _convertPdfToImage.convert(url, page).then((value) {
      totalPage = value['total_page'];
      return value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Document Viewer
        FutureBuilder<Map>(
          future: _convertPdf(widget.fileUrl, initPage),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (snapshot.connectionState == ConnectionState.done) {
              return SizedBox(
                height: snapshot.data!['height'],
                width: snapshot.data!['width'],
                child: InteractiveViewer(
                  minScale: 0.1,
                  maxScale: 5.0,
                  constrained: false,
                  child: Stack(
                    children: [
                      // PDF
                      Image.file(
                        snapshot.data!['image'],
                        fit: BoxFit.cover,
                      ),

                      // Signature
                      _SignatureBox(
                        canvasHeight: snapshot.data!['height'],
                        canvasWidth: snapshot.data!['width'],
                        boxHeight: widget.boxHeight,
                        boxWidth: widget.boxWidth,
                        child: widget.child,
                        boxStream: widget.stream,
                        pageNumber: 1,
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return const Center(
                child: Text('No Document'),
              );
            }
          },
        ),

        // Button move page
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.grey,
                ),
                iconSize: 25,
                onPressed: () => (initPage > 1) ? setState(() => initPage--) : null,
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                ),
                iconSize: 25,
                onPressed: () => (initPage < totalPage) ? setState(() => initPage++) : null,
              ),
            ],
          ),
        ),

        //--
      ],
    );
  }
}

/// Signature Box
/// ----
/// Kotak gambar tanda tangan yang bisa di geser dengan cara menekan lama si box tersebut
///
class _SignatureBox extends StatefulWidget {
  final double canvasHeight;
  final double canvasWidth;
  final double boxHeight, boxWidth;

  final int pageNumber;

  final StreamController<Map> boxStream;

  final Widget child;

  const _SignatureBox({
    Key? key,
    required this.canvasHeight,
    required this.canvasWidth,
    this.boxHeight = 160,
    this.boxWidth = 40,
    required this.boxStream,
    required this.child,
    required this.pageNumber,
  }) : super(key: key);

  @override
  __SignatureBoxState createState() => __SignatureBoxState();
}

class __SignatureBoxState extends State<_SignatureBox> {
  double initX = 0.0, initY = 0.0;
  Offset _offset = Offset.zero;
  double _updateScale = 1.0, _initialScale = 1.0;

  @override
  void initState() {
    // Initial location box in canvas
    initX = (widget.canvasWidth - 200) / 2;
    initY = (widget.canvasHeight - 200) / 2;
    _offset = Offset(initX, initY);

    // Initial Box Stream
    widget.boxStream.sink.add({
      'page': widget.pageNumber,
      'posx': initX,
      'posy': initY,
      'height': widget.boxHeight,
      'width': widget.boxWidth,
      'llx': initX,
      'lly': initY + widget.boxHeight,
      'urx': initX + widget.boxWidth,
      'ury': initY,
      'llx_trans': initX,
      'lly_trans': widget.canvasHeight - (initY + widget.boxHeight),
      'urx_trans': initX + widget.boxWidth,
      'ury_trans': widget.canvasHeight - initY,
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: Transform.scale(
        scale: _updateScale,
        child: GestureDetector(
          onLongPressStart: (details) {
            setState(() {
              initX = details.globalPosition.dx;
              initY = details.globalPosition.dy;
            });
          },
          onLongPressMoveUpdate: (details) {
            double dx, dy;
            setState(() {
              dx = details.globalPosition.dx - initX;
              dy = details.globalPosition.dy - initY;
              initX = details.globalPosition.dx;
              initY = details.globalPosition.dy;
              _offset = _offset + Offset(dx, dy);
            });

            widget.boxStream.sink.add({
              'page': widget.pageNumber,
              'posx': _offset.dx,
              'posy': _offset.dy,
              'height': widget.boxHeight,
              'width': widget.boxWidth,
              'llx': _offset.dx,
              'lly': _offset.dy + widget.boxHeight,
              'urx': _offset.dx + widget.boxWidth,
              'ury': _offset.dy,
              "llx_trans": (_offset.dx).toInt(),
              "lly_trans": (widget.canvasHeight - (_offset.dy + widget.boxHeight)).toInt(),
              "urx_trans": (_offset.dx + widget.boxWidth).toInt(),
              "ury_trans": (widget.canvasHeight - _offset.dy).toInt(),
            });
          },
          onScaleStart: (details) {
            _initialScale = _updateScale;
          },
          onScaleUpdate: (details) {
            setState(() {
              _updateScale = _initialScale * details.scale;
            });
          },
          child: Container(
            height: widget.boxHeight,
            width: widget.boxWidth,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
