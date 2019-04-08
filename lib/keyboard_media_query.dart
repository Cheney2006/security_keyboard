import 'package:flutter/material.dart';
import 'package:security_keyboard/keyboard_manager.dart';

/// @desp: 用于键盘弹出的时候页面可以滚动到输入框的位置
/// @time 2019/3/28 4:50 PM
/// @author chenyun
class KeyboardMediaQuery extends StatefulWidget {
  final Widget child;

  KeyboardMediaQuery({this.child}) : assert(child != null);

  @override
  State<StatefulWidget> createState() => KeyboardMediaQueryState();
}

class KeyboardMediaQueryState extends State<KeyboardMediaQuery> {
  @override
  Widget build(BuildContext context) {
    var data = MediaQuery.of(context);

    ///消息传递，更新控件边距
    return MediaQuery(
        child: widget.child,
        data: data.copyWith(
            viewInsets: data.viewInsets
                .copyWith(bottom: KeyboardManager.keyboardHeight)));
  }

  ///通知更新
  update() {
    setState(() => {});
  }
}
