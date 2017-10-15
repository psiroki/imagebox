import "dart:async";
import "dart:html";

typedef void SelectionChangeCallback(Tool tool, bool selecting);
typedef void EventHandler<T extends Event>(T event);

class _ClassChange {
  _ClassChange(target, className, value);

  void restore() => target.classes.toggle(className, value);

  Element target;
  String className;
  bool value;
}

class Tool {
  Tool(this.name, this.selectCallback);

  final String name;
  final SelectionChangeCallback selectCallback;

  void select(bool selecting) {
    if (selecting) return selectCallback(this, selecting);

    try {
      return selectCallback(this, selecting);
    } finally {
      this.removeListeners();
      this.restoreClasses();
      this.removeAddedElements();
    }
  }

  void toggle(Element target, String className, bool value) {
    _classChanges.add(new _ClassChange(target, className, target.classes.contains(className)));
    target.classes.toggle(className, value);
  }

  void addListener<T extends Event>(ElementStream<T> stream, EventHandler<T> callback) {
    _listeners.add(stream.listen(callback));
  }

  void addElement(Element e) {
    _addedNodes.add(e);
  }

  void elementRemoved(Element element) {
    _addedNodes.removeWhere((Node n) => n == element);
  }

  void removeListeners() {
    _listeners.forEach((StreamSubscription sub) => sub.cancel());
    _listeners.clear();
  }

  void restoreClasses() {
    _classChanges.forEach((_ClassChange change) => change.restore());
    _classChanges.clear();
  }

  void removeAddedElements() {
    _addedNodes.forEach((Node e) => e.remove());
    _addedNodes.clear();
  }

  String get buttonSelector => ".${name}Button";

  List<StreamSubscription> _listeners = [];
  List<Node> _addedNodes = [];
  List<_ClassChange> _classChanges = [];
}
