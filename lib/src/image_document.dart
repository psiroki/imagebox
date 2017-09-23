import "dart:html";
import "dart:async";
import "dart:typed_data";
import "dart:math" as math;

import "exif.dart";
import "pipeline.dart";
import "pixel.dart";

class ImageDocumentView {
  ImageDocumentView(Element viewTemplate, this.doc) {
    _view = viewTemplate.clone(true);
    _canvasParent = _view.querySelector(".canvasParent");
    _canvasParent.append(doc.backingCanvas);
    _view.querySelector(".closeButton").onClick.listen((_) {
      _view.remove();
    });
  }

  Element get view => _view;

  final ImageDocument doc;

  Element _canvasParent;
  Element _view;
}

class ImageDocument {
  static Future<ImageDocument> load(Blob blob, Pipeline pipeline) async {
    List<Future> futures = <Future<dynamic>>[
      _loadImage(blob),
      ExifInfo.fromBlob(blob)
    ];
    List objects = await Future.wait(futures);
    ExifInfo info = objects[1];
    return new ImageDocument(objects[0] as ImageElement,
        pipeline: pipeline, exifInfo: info);
  }

  static Future<ImageElement> _loadImage(Blob blob) {
    Completer<ImageElement> completer = new Completer();
    String blobUrl = Url.createObjectUrlFromBlob(blob);
    ImageElement image = new ImageElement();
    image.onAbort.listen((Event event) {
      completer.completeError("Image loading aborted");
    });
    image.onError.listen((Event event) {
      completer.completeError("Image loading error");
    });
    image.onLoad.listen((Event event) {
      Url.revokeObjectUrl(blobUrl);
      completer.complete(image);
    });
    image.src = blobUrl;
    return completer.future;
  }

  ImageDocument(ImageElement image,
      {Pipeline pipeline, ExifInfo exifInfo, CanvasElement backingCanvas}) {
    int o = exifInfo?.orientation ?? 0;
    bool flip = o != null && o > 4;
    _width = !flip ? image.naturalWidth : image.naturalHeight;
    _height = flip ? image.naturalWidth : image.naturalHeight;
    if (backingCanvas == null) {
      _backingCanvas = new CanvasElement(
        width: _width,
        height: _height,
      );
    } else {
      _backingCanvas = backingCanvas;
      _backingCanvas.width = _width;
      _backingCanvas.height = _height;
    }

    _context = _backingCanvas.getContext("2d");
    _context.save();
    if (o > 0) {
      Float32List mat = new Float32List(6);
      int x = o <= 4 ? 0 : 1;
      int y = o <= 4 ? 1 : 0;
      double xs = ((o & 3) >> 1) != 0 ? -1.0 : 1.0;
      double ys = (((o - 1) & 3) >> 1) != 0 ? -1.0 : 1.0;
      mat[2 * x] = xs;
      mat[2 * y] = 0.0;
      mat[2 * x + 1] = 0.0;
      mat[2 * y + 1] = ys;
      mat[4] = -_width * math.min(0.0, xs);
      mat[5] = -_height * math.min(0.0, ys);
      _context.transform(mat[0], mat[1], mat[2], mat[3], mat[4], mat[5]);
    }
    _context.drawImage(image, 0, 0);
    PixelData pixels = pipeline.process(_context);
    _backingCanvas.width = pixels.width;
    _backingCanvas.height = pixels.height;
    _context.clearRect(0, 0, pixels.width, pixels.height);
    _context.putImageData(pixels.createImageData(_context), 0, 0);
    _context.restore();
  }

  CanvasElement get backingCanvas => _backingCanvas;

  int _width;
  int _height;
  CanvasRenderingContext2D _context;
  CanvasElement _backingCanvas;
}
