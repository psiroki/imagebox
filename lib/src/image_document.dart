import "dart:html";
import "dart:async";
import "dart:typed_data";
import "dart:math" as math;

import "package:crc32/crc32.dart";

import "../imagebox.dart";

import "exif.dart";
import "pipeline.dart";
import "pixel.dart";
import "tool.dart";
import "mask.dart";
import "control.dart";

class _SelectionStackElement {
  Mask mask;
  CanvasElement highlight;
  int refColor;
}

class ImageDocumentView {
  ImageDocumentView(this.app, Element viewTemplate, this.doc) {
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
    _tools = [new Tool("eraser", (Tool tool, bool doSelect) {
      Console console = window.console;
      if(doSelect) {
        var createAxis = (orientation) {
          SpanElement axis = new SpanElement();
          axis.classes.add("${orientation}Ants");
          axis.classes.add("${orientation}Axis");
          axis.classes.add("hideCursor");
          return axis;
        };

        List<SpanElement> axis = [
          createAxis("vertical"),
          createAxis("horizontal")
        ];

        axis.forEach((a) {
          _canvasParent.append(a);
          tool.addElement(a);
        });

        CanvasElement canvas = doc.backingCanvas;
        var canvasX = (MouseEvent event) => event.offset.x;
        var canvasY = (MouseEvent event) => event.offset.y;
        tool.addListener(canvas.onMouseMove, (MouseEvent event) {
          num x = canvasX(event);
          num y = canvasY(event);
          axis[0].style.left = "${x}px";
          axis[1].style.top = "${y}px";
          if (x < 0 || x >= canvas.offsetWidth || y < 0 || y >= canvas.offsetHeight) {
            axis[0].style.display = "none";
            axis[1].style.display = "none";
          } else {
            axis[0].style.display = "";
            axis[1].style.display = "";
          }
        });
        canvas.tabIndex = 0;
        List<_SelectionStackElement> selectionStack = [];

        var removeHighlight = (_SelectionStackElement selection) {
          if (selection.highlight == null) return;
          Element p = selection.highlight.parent;
          if (p != null) selection.highlight.remove();
          tool.elementRemoved(selection.highlight);
        };

        var execute = (bool commit) {
          if (selectionStack.isNotEmpty) {
            var selection = selectionStack.removeLast();
            if (commit) {
              selection.mask.imageData = new PixelData.fromCanvas(doc.backingCanvas);
              selection.mask.paint(color: selection.refColor);
              selection.mask.imageData.setCanvasContents(doc.backingCanvas);
            }
            removeHighlight(selection);
          }
        };

        tool.addListener(canvas.onKeyDown, (KeyboardEvent event) {
          if (event.which == 13) {
            event.preventDefault();
            event.stopPropagation();
            execute(true);
          } else if (event.which == 8 || event.which == 46) {
            event.preventDefault();
            event.stopPropagation();
            execute(false);
          }
        });
        tool.addListener(canvas.onClick, (MouseEvent event) {
          canvas.focus();
          num x = canvasX(event);
          num y = canvasY(event);
          _SelectionStackElement current;
          if (selectionStack.isNotEmpty) {
            current = selectionStack.first;
          } else {
            Mask mask = new Mask(new PixelData.fromCanvas(doc.backingCanvas));
            current = new _SelectionStackElement()
              ..mask = mask
              ..highlight = null
              ..refColor = mask.referenceColor;
            selectionStack.add(current);
          }

          int refColor = current.refColor;

          console.log("Testing for color: ${refColor.toRadixString(16).padLeft(8, '0')}");
          current.mask.fill(x, y, pixelTest: (pixel) => pixel != refColor);

          removeHighlight(current);

          CanvasElement fillHighlight = current.mask.createHighlightElement("highlightCanvas");
          _canvasParent.append(fillHighlight);
          tool.addElement(fillHighlight);
          current.highlight = fillHighlight;
        });
        tool.toggle(canvas, "hideCursor", true);
        tool.toggle(_canvasParent, "hideCursor", true);
      } else {
        // everything's removed automatically
        doc.backingCanvas.tabIndex = -1;
      }
    })];
    _tools.forEach((Tool t) {
      _bindBarButton(t.buttonSelector, (_) {
        if(_tool == t) {
          _tool.select(false);
          _tool = null;
        } else {
          if (_tool != null)
            _tool.select(false);
          _tool = t;
          _tool.select(true);
        }
        _syncTool();
      });
    });
    _bindBarButton(".recropButton", (_) {
      app.handlePixelData(new PixelData.fromCanvas(doc.backingCanvas), filename: doc.filename);
    });
  }

  void appendTo(Element parent, [Node before]) {
    Element saveJpgButton = _ownBar.querySelector(".saveJpgButton");
    Element qualityOutput = _ownBar.querySelector(".jpgQualityNum");
    qualityOutput.style.lineHeight = "";
    parent.insertBefore(view, before);
    if (saveJpgButton != null) {
      qualityOutput.style.lineHeight = "${saveJpgButton.offsetHeight}px";
    }
  }

  void _syncTool() {
    _ownBar.classes.toggle("toolSelected", _tool != null);
    _tools.forEach((Tool t) {
      _ownBar.querySelectorAll(t.buttonSelector).forEach((Node n) {
        if (n is Element) n.classes.toggle("checked", t == _tool);
      });
    });
  }

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
  final ImageBoxApp app;
  Element get view => _view;

  Tool _tool;
  List<Tool> _tools;

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
    return new ImageDocument(image: objects[0] as ImageElement,
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

  ImageDocument({ImageElement image, PixelData pixels,
      Pipeline pipeline, ExifInfo exifInfo, CanvasElement backingCanvas, this.filename}) {
    if (image != null) {
      int o = exifInfo?.orientation ?? 0;
      bool flip = o > 4;
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
      _context.restore();
      pixels = pipeline.process(context: _context);
    } else {
      pixels = pipeline.process(pixels: pixels);
      if (backingCanvas == null) {
        _backingCanvas = new CanvasElement(
          width: pixels.width,
          height: pixels.height,
        );
      } else {
        _backingCanvas = backingCanvas;
      }
    }
    _width = pixels.width;
    _height = pixels.height;
    _backingCanvas.width = pixels.width;
    _backingCanvas.height = pixels.height;
    _context ??= _backingCanvas.getContext("2d");
    _context.clearRect(0, 0, pixels.width, pixels.height);
    _context.putImageData(pixels.createImageData(_context), 0, 0);
    pixels.setCanvasContents(_backingCanvas);
  }

  CanvasElement get backingCanvas => _backingCanvas;

  int get referenceColor => _lastReferenceColor;

  String filename;

  int _width;
  int _height;
  int _lastReferenceColor;
  CanvasRenderingContext2D _context;
  CanvasElement _backingCanvas;
}
