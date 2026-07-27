import 'package:flutter/material.dart';

class EditorialPage extends StatelessWidget {
  const EditorialPage({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.horizontalPadding,
    this.scrollable = true,
    this.bottomPadding = 36,
  });

  final Widget child;
  final double maxWidth;
  final double? horizontalPadding;
  final bool scrollable;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding =
        horizontalPadding ??
        (width >= 840
            ? 36.0
            : width < 360
            ? 16.0
            : 20.0);

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 20, padding, bottomPadding),
          child: child,
        ),
      ),
    );

    return SafeArea(
      child: scrollable
          ? SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: content,
            )
          : content,
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 2,
    this.desktopColumns = 4,
    this.childAspectRatio = .62,
    this.spacing = 14,
    this.desktopBreakpoint = 840,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int desktopColumns;
  final double childAspectRatio;
  final double spacing;
  final double desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= desktopBreakpoint
            ? desktopColumns
            : mobileColumns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (_, index) => children[index],
        );
      },
    );
  }
}
