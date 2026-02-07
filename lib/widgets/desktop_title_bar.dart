import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class DesktopTitleBar extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double height;

  const DesktopTitleBar({
    Key? key,
    this.leading,
    this.title,
    this.actions,
    this.backgroundColor,
    this.height = 32.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      height: height,
      color: backgroundColor ?? (isDark ? Colors.grey[900] : Colors.white),
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: MoveWindow(
              child: title != null 
                  ? Align(alignment: Alignment.centerLeft, child: title) 
                  : const SizedBox.shrink(),
            ),
          ),
          if (actions != null) ...actions!,
          WindowButtons(colors: WindowButtonColors(
            normal: Colors.transparent,
            mouseOver: isDark ? Colors.white12 : Colors.black12,
            mouseDown: isDark ? Colors.white24 : Colors.black24,
            iconNormal: isDark ? Colors.white : Colors.black87,
            iconMouseOver: isDark ? Colors.white : Colors.black87,
            iconMouseDown: isDark ? Colors.white : Colors.black87,
          )),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  final WindowButtonColors colors;
  
  const WindowButtons({Key? key, required this.colors}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MinimizeWindowButton(colors: colors),
        WindowButton(
          colors: colors,
          icon: appWindow.isMaximized 
              ? const RestoreIcon(color: Colors.white)
              : const MaximizeIcon(color: Colors.white),
          onPressed: () => appWindow.maximizeOrRestore(),
        ),
        CloseWindowButton(colors: WindowButtonColors(
          normal: Colors.transparent,
          mouseOver: Colors.red,
          mouseDown: Colors.red[700],
          iconNormal: colors.iconNormal,
          iconMouseOver: Colors.white,
          iconMouseDown: Colors.white,
        )),
      ],
    );
  }
}
