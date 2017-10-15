import "dart:html";
import "dart:async";
import "dart:typed_data";
import "dart:math" as math;

import "package:crc32/crc32.dart";

import "exif.dart";
import "pipeline.dart";
import "pixel.dart";
import "control.dart";

class ImageDocumentView {
  ImageDocumentView(Element viewTemplate, this.doc) {
    _view = viewTemplate.clone(true);
    _canvasParent = _view.querySelector(".canvasParent");
    _canvasParent.append(doc.backingCanvas);
    _view.querySelector(".closeButton").onClick.listen((_) {
      _view.remove();
    });
    _ownBar = _view.querySelector(".snackBar");
    Element qualityOutput = _ownBar.querySelector(".jpgQualityNum");
    _jpgQualityInput = _ownBar.querySelector(".jpgQuality");
    bindValues(_jpgQualityInput, qualityOutput, (String s) => s.padLeft(3, "\u2007"));
    _bindBarButton(".saveJpgButton", _saveJpg);
    _bindBarButton(".savePngButton", _savePng);
  }

  void appendTo(Element parent) {
    Element saveJpgButton = _ownBar.querySelector(".saveJpgButton");
    Element qualityOutput = _ownBar.querySelector(".jpgQualityNum");
    qualityOutput.style.lineHeight = "";
    parent.append(view);
    if (saveJpgButton != null) {
      qualityOutput.style.lineHeight = "${saveJpgButton.offsetHeight}px";
    }
  }

  Element get view => _view;

  void _bindBarButton(String selector, void clickHandler(MouseEvent event)) {
    _ownBar.querySelectorAll(selector).forEach((Element e) {
      e.onClick.listen(clickHandler);
    });
  }

  void _saveJpg(MouseEvent event) {
    double quality = double.parse(_jpgQualityInput.value) * 1e-2;
    _handleSave("jpg", "image/jpeg", quality);
  }

  void _savePng(MouseEvent event) {
    _handleSave("png", "image/png");
  }

  void _handleSave(String suffix, String type, [Object extra]) {
    bool forceDataPopup = window.navigator.userAgent.contains(blobUnfriendlyUserAgentMatcher);
    if (forceDataPopup) {
      window.open(doc.backingCanvas.toDataUrl(type, extra), "_blank");
    } else {
      doc.backingCanvas.toBlob((blob) => _handleDownload(doc.filename, suffix, blob), type, extra);
    }
  }

  void _handleDownload(String originalFilename, String suffix, Blob blob) {
    FileReader reader = new FileReader();
    reader.onLoad.listen((ProgressEvent event) {
      String crc = CRC32.compute(reader.result).toRadixString(16).padLeft(8, '0');
      originalFilename ??= "image";
      int dot = originalFilename.lastIndexOf('.');
      if (dot >= 0) originalFilename = originalFilename.substring(0, dot);
      String filename = "${originalFilename}_${crc}.${suffix}";
      String blobUrl = Url.createObjectUrlFromBlob(blob);
      AnchorElement a = document.createElement("a");
      a.href = blobUrl;
      a.download = filename;
      a.click();
      Url.revokeObjectUrl(blobUrl);
    });
    reader.readAsArrayBuffer(blob);
  }

  final ImageDocument doc;

  InputElement _jpgQualityInput;
  Element _canvasParent;
  Element _ownBar;
  Element _view;

  static final RegExp blobUnfriendlyUserAgentMatcher = new RegExp(r"\biPad\b|\biPhone\b|\biPod\b");
}

class ImageDocument {
  static Future<ImageDocument> load(Blob blob, Pipeline pipeline) async {
    String filename = blob is File ? blob.name : null;
    List<Future> futures = <Future<dynamic>>[_loadImage(blob), ExifInfo.fromBlob(blob)];
    List objects = await Future.wait(futures);
    ExifInfo info = objects[1];
    return new ImageDocument(objects[0] as ImageElement,
        pipeline: pipeline, exifInfo: info, filename: filename);
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
      {Pipeline pipeline, ExifInfo exifInfo, CanvasElement backingCanvas, this.filename}) {
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

  String filename;

  int _width;
  int _height;
  CanvasRenderingContext2D _context;
  CanvasElement _backingCanvas;
}
