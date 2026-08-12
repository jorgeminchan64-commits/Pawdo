import 'package:flutter/widgets.dart';

class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  });

  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<Widget?> _children;

  @override
  void initState() {
    super.initState();
    _children = List<Widget?>.filled(widget.builders.length, null);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.builders.length != widget.builders.length) {
      _children = List<Widget?>.generate(
        widget.builders.length,
        (index) => index < _children.length ? _children[index] : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.builders.isNotEmpty);
    assert(widget.index >= 0 && widget.index < widget.builders.length);
    _children[widget.index] ??= widget.builders[widget.index](context);
    return IndexedStack(
      index: widget.index,
      children: List<Widget>.generate(
        widget.builders.length,
        (index) => _children[index] ?? const SizedBox.shrink(),
      ),
    );
  }
}
