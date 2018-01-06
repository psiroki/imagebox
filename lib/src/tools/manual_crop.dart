import "dart:html";
import "dart:math" as math;

import "../loupe.dart";
import "../axes.dart";
import "../tool.dart";
import "../image_document.dart";
import "../pixel.dart";
import "../app.dart";

class ManualCrop extends ToolHandler {
  ManualCrop(this.app, this.doc, this._canvasParent) : super("manualCrop");

  @override
  void select() {
    new Loupe(tool, doc.backingCanvas);
    new Axes(tool, doc.backingCanvas, _canvasParent);
    doc.backingCanvas.tabIndex = 0;
    _frame = null;
    _points = [];
    tool.addListener(doc.backingCanvas.onClick, (MouseEvent event) {
      _points.add(event.offset);
      if (_points.length > 2) _points.removeAt(0);
      _adjustFrame(_points);
    });
    tool.addListener(doc.backingCanvas.onMouseMove, (MouseEvent event) {
      if (_points.length != 1 || _frame == null) return;
      List<Point<num>> newPoints = [_points.last];
      newPoints.add(event.offset);
      _adjustFrame(newPoints);
    });

    tool.addListener(doc.backingCanvas.onKeyDown, (KeyboardEvent event) {
      if (event.which == 13) {
        event.preventDefault();
        event.stopPropagation();
        commit();
      } else if (event.which == 8 || event.which == 46) {
        event.preventDefault();
        event.stopPropagation();
        rollback();
      }
    });
  }

  void deselect() {
    // everything's removed automatically
    doc.backingCanvas.tabIndex = -1;
  }

  void commit() {
    if (_points.length < 2) return;
    CanvasRenderingContext2D context = doc.backingCanvas.context2D;
    List<int> coords = new List(4);
    for (int i = 0; i < 2; ++i) {
      coords[i * 2] = _points[i].x;
      coords[i * 2 + 1] = _points[i].y;
    }
    for (int i = 0; i < 2; ++i) {
      if (coords[i] > coords[i + 2]) {
        num save = coords[i];
        coords[i] = coords[i + 2];
        coords[i + 2] = save;
      }
      coords[i + 2] -= coords[i] - 1;
    }
    ImageData imageData = context.getImageData(coords[0], coords[1], coords[2], coords[3]);
    app.handlePixelData(new WrappedImageData(imageData));
    dismiss();
  }

  void rollback() => dismiss();

  void dismiss() {
    _frame.remove();
    _frame = null;
    _points.clear();
  }

  void _adjustFrame(List<Point<num>> points) {
    if (_frame == null) {
      _frame = new DivElement();
      tool.addElement(_frame);
      _frame.className = "selectionFrame";
      _canvasParent.append(_frame);
    }
    num x1 = points.map((p) => p.x).reduce(math.min);
    num y1 = points.map((p) => p.y).reduce(math.min);
    num x2 = points.map((p) => p.x).reduce(math.max);
    num y2 = points.map((p) => p.y).reduce(math.max);
    _frame.style.left = "${x1}px";
    _frame.style.top = "${y1}px";
    _frame.style.width = "${x2 - x1 + 1}px";
    _frame.style.height = "${y2 - y1 + 1}px";
  }

  List<Point<num>> _points = [];
  DivElement _frame;

  final ImageBoxApp app;
  final ImageDocument doc;
  final Element _canvasParent;
}
