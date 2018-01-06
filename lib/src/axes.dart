import "dart:html";

import "tool.dart";

/// An axxis add-on for tools
class Axes {
  Axes(Tool tool, CanvasElement canvas, Element canvasParent) {
    List<SpanElement> axis = ["vertical", "horizontal"].map((String orientation) {
      SpanElement axis = new SpanElement();
      axis.classes.add("${orientation}Ants");
      axis.classes.add("${orientation}Axis");
      axis.classes.add("hideCursor");
      return axis;
    }).toList();

    axis.forEach((a) {
      canvasParent.parent.append(a);
      tool.addElement(a);
    });

    tool.addListener(canvas.onMouseMove, (MouseEvent event) {
      num x = event.offset.x + 3;
      num y = event.offset.y + 3;
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

    tool.toggle(canvas, "hideCursor", true);
    tool.toggle(canvasParent, "hideCursor", true);
  }
}
