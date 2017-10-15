import "dart:html";

import "tool.dart";

/// A loupe add-on for tools
class Loupe {
  Loupe(this.tool, this.sourceCanvas) {
    _outer = template.clone(true);
    _zoomCanvas = _outer.querySelector("canvas");

    document.body.append(_outer);
    tool.addElement(_outer);

    _zoomCanvas.width = (_zoomCanvas.offsetWidth * window.devicePixelRatio).floor();
    _zoomCanvas.height = (_zoomCanvas.offsetHeight * window.devicePixelRatio).floor();
    _zoom = _zoomCanvas.getContext("2d");
    _zoom.strokeStyle = "black";

    halfViewWidth = _zoomCanvas.offsetWidth * (0.5 * 0.125);
    halfViewHeight = _zoomCanvas.offsetHeight * (0.5 * 0.125);

    tool.addListener(sourceCanvas.onMouseMove, _handleMouseMove);
    tool.addListener(sourceCanvas.onMouseLeave, (_) {
      _outer.style.display = "none";
    });
    tool.addListener(sourceCanvas.onMouseEnter, (_) {
      _outer.style.display = "";
    });
  }

  void _handleMouseMove(MouseEvent event) {
    Point<num> position = event.offset;
    Point<num> abs = position + sourceCanvas.documentOffset;
    _outer.style.left = "${abs.x}px";
    _outer.style.top = "${abs.y}px";
    double scale = sourceCanvas.width / sourceCanvas.offsetWidth;
    position *= scale;
    _zoom.clearRect(0, 0, _zoomCanvas.width, _zoomCanvas.height);
    _zoom.imageSmoothingEnabled = false;
    _zoom.drawImageScaledFromSource(sourceCanvas,
      position.x - halfViewWidth + 1, position.y - halfViewHeight + 1,
      2 * halfViewWidth - 1, 2 * halfViewHeight - 1,
      0, 0, _zoomCanvas.width, _zoomCanvas.height);
    _zoom.imageSmoothingEnabled = true;
    _drawCrosshair();
    _zoom.save();
    _zoom.strokeStyle = "white";
    _zoom.translate(-1, -1);
    _drawCrosshair();
    _zoom.restore();
  }

  void _drawCrosshair() {
    _zoom.beginPath();
    _zoom.moveTo(_zoomCanvas.width * 0.5, 0);
    _zoom.lineTo(_zoomCanvas.width * 0.5, _zoomCanvas.height + 1);
    _zoom.moveTo(0, _zoomCanvas.height * 0.5);
    _zoom.lineTo(_zoomCanvas.width + 1, _zoomCanvas.height * 0.5);
    _zoom.stroke();
  }

  final Tool tool;
  final CanvasElement sourceCanvas;

  double halfViewWidth, halfViewHeight;
  CanvasRenderingContext2D _zoom;
  Element _outer;
  CanvasElement _zoomCanvas;

  static Element get template => _template ??= document.querySelector(".loupe")..remove();
  static Element _template;
}
