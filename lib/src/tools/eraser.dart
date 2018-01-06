import "dart:html";

import "../loupe.dart";
import "../axes.dart";
import "../tool.dart";
import "../mask.dart";
import "../image_document.dart";
import "../pixel.dart";
import "../app.dart";

class _SelectionStackElement {
  Mask mask;
  CanvasElement highlight;
  int refColor;
  Tool tool;

  void removeHighlight() {
    if (highlight == null) return;
    highlight.remove();
    tool.elementRemoved(highlight);
  }

  void execute(ImageDocument doc) {
    mask.imageData = new PixelData.fromCanvas(doc.backingCanvas);
    mask.paint(color: refColor);
    mask.imageData.setCanvasContents(doc.backingCanvas);
    removeHighlight();
  }
}

class Eraser extends ToolHandler {
  Eraser(ImageBoxApp app, this.doc, this._canvasParent) : super("eraser");

  @override
  void select() {
    Console console = window.console;
    new Loupe(tool, doc.backingCanvas);
    new Axes(tool, doc.backingCanvas, _canvasParent);

    CanvasElement canvas = doc.backingCanvas;

    canvas.tabIndex = 0;
    _selectionStack = [];

    tool.addListener(canvas.onKeyDown, (KeyboardEvent event) {
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
    tool.addListener(canvas.onClick, (MouseEvent event) {
      canvas.focus();
      num x = event.offset.x;
      num y = event.offset.y;
      _SelectionStackElement current;
      if (_selectionStack.isNotEmpty) {
        current = _selectionStack.first;
      } else {
        Mask mask = new Mask(new PixelData.fromCanvas(doc.backingCanvas));
        current = new _SelectionStackElement()
          ..mask = mask
          ..highlight = null
          ..refColor = mask.referenceColor
          ..tool = tool;
        _selectionStack.add(current);
      }

      int refColor = current.refColor;

      console.log("Testing for color: ${refColor.toRadixString(16).padLeft(8, '0')}");
      current.mask.fill(x, y, pixelTest: (pixel) => pixel != refColor);

      current.removeHighlight();

      CanvasElement fillHighlight = current.mask.createHighlightElement("highlightCanvas");
      _canvasParent.append(fillHighlight);
      tool.addElement(fillHighlight);
      current.highlight = fillHighlight;
    });
  }

  @override
  void deselect() {
    // everything's removed automatically
    doc.backingCanvas.tabIndex = -1;
  }

  @override
  void commit() {
    if (_selectionStack.isNotEmpty) _selectionStack.removeLast().execute(doc);
  }

  @override
  void rollback() {
    if (_selectionStack.isNotEmpty) _selectionStack.removeLast().removeHighlight();
  }

  final ImageDocument doc;
  final Element _canvasParent;

  List<_SelectionStackElement> _selectionStack;
}
