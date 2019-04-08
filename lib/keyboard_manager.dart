import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:security_keyboard/keyboard_controller.dart';
import 'package:security_keyboard/keyboard_media_query.dart';

typedef GetKeyboardHeight = double Function();
typedef KeyboardBuilder = Widget Function(
    BuildContext context, KeyboardController controller);

/// @desp: 键盘管理
/// @time 2019/3/28 5:10 PM
/// @author chenyun
class KeyboardManager {
  ///解码器
  static JSONMethodCodec _codec = const JSONMethodCodec();

  ///当前键盘配置
  static KeyboardConfig _currentKeyboard;

  ///键盘类型配置列表
  static Map<String, KeyboardConfig> _keyboards = {};

  ///当前页面 context
  static BuildContext _context;

  ///显示悬浮控件
  static OverlayEntry _keyboardEntry;

  ///键盘输入变更监听
  static KeyboardController _keyboardController;
  static GlobalKey<KeyboardPageState> _pageKey;
  static bool isInterceptor = false;

  ///键盘高度
  static double get keyboardHeight => _keyboardHeight;
  static double _keyboardHeight;

  ///初始化键盘监听并且传递当前页面的context
  static init(BuildContext context) {
    _context = context;
    interceptorInput();
  }

  ///拦截键盘交互
  static interceptorInput() {
    if (isInterceptor) return;
    isInterceptor = true;
    BinaryMessages.setMockMessageHandler("flutter/textinput",
        (ByteData data) async {
      var methodCall = _codec.decodeMethodCall(data);
      switch (methodCall.method) {
        case 'TextInput.show':
          if (_currentKeyboard != null) {
            openKeyboard();
            return _codec.encodeSuccessEnvelope(null);
          } else {
            return await _sendPlatformMessage("flutter/textinput", data);
          }
          break;
        case 'TextInput.hide':
          if (_currentKeyboard != null) {
            hideKeyboard();
            return _codec.encodeSuccessEnvelope(null);
          } else {
            return await _sendPlatformMessage("flutter/textinput", data);
          }
          break;
        case 'TextInput.setEditingState':
          var editingState = TextEditingValue.fromJSON(methodCall.arguments);
          if (editingState != null && _keyboardController != null) {
            _keyboardController.value = editingState;
            return _codec.encodeSuccessEnvelope(null);
          }
          break;

        ///切换输入框时，会调用该回调,切换时键盘会隐藏。所以改成 hideKeyboard(animation: false);或者注释这判断,注释就不会重新创建键盘
        case 'TextInput.clearClient':
          hideKeyboard(animation: false);
          clearKeyboard();
          break;
        case 'TextInput.setClient':
          var setInputType = methodCall.arguments[1]['inputType'];
          InputClient client;

          ///找出自定义输入类型对应的键盘
          _keyboards.forEach((inputType, keyboardConfig) {
            if (inputType == setInputType['name']) {
              client = InputClient.fromJSON(methodCall.arguments);
              clearKeyboard();
              _currentKeyboard = keyboardConfig;
              _keyboardController = KeyboardController(client: client)
                ..addListener(() {
                  var callbackMethodCall = MethodCall(
                      "TextInputClient.updateEditingState", [
                    _keyboardController.client.connectionId,
                    _keyboardController.value.toJSON()
                  ]);
                  BinaryMessages.handlePlatformMessage("flutter/textinput",
                      _codec.encodeMethodCall(callbackMethodCall), (data) {});
                });
            }
          });
          if (client != null) {
            await _sendPlatformMessage("flutter/textinput",
                _codec.encodeMethodCall(MethodCall('TextInput.hide')));
            return _codec.encodeSuccessEnvelope(null);
          } else {
            hideKeyboard(animation: false);
            clearKeyboard();
          }
          break;
      }
      ByteData response = await _sendPlatformMessage("flutter/textinput", data);
      return response;
    });
  }

  static Future<ByteData> _sendPlatformMessage(
      String channel, ByteData message) {
    final Completer<ByteData> completer = Completer<ByteData>();
    ui.window.sendPlatformMessage(channel, message, (ByteData reply) {
      try {
        completer.complete(reply);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: 'during a platform message response callback',
        ));
      }
    });
    return completer.future;
  }

  ///注册输入类型与键盘映射
  static addKeyboard(SecurityTextInputType inputType, KeyboardConfig config) {
    _keyboards[inputType.name] = config;
  }

  ///显示键盘
  static openKeyboard() {
    ///键盘已经打开
    if (_keyboardEntry != null) return;

    _pageKey = GlobalKey<KeyboardPageState>();
    _keyboardHeight = _currentKeyboard.getHeight();

    ///根据键盘高度，使键盘滚动到输入框位置
    KeyboardMediaQueryState queryState = _context
            .ancestorStateOfType(const TypeMatcher<KeyboardMediaQueryState>())
        as KeyboardMediaQueryState;
    queryState.update();

    var tempKey = _pageKey;

    ///创建OverlayEntry
    _keyboardEntry = OverlayEntry(builder: (ctx) {
      if (_currentKeyboard != null && _keyboardHeight != null) {
        ///键盘配置与键盘高度不为空，则创建对应的键盘
        return KeyboardPage(
            key: tempKey,
            child: Builder(builder: (ctx) {
              return _currentKeyboard.builder(ctx, _keyboardController);
            }),
            height: _keyboardHeight);
      } else {
        return Container();
      }
    });

    ///往Overlay中插入插入OverlayEntry
    Overlay.of(_context).insert(_keyboardEntry);
  }

  ///键盘是否显示中
  static get isShowKeyboard => _keyboardEntry != null;

  ///隐藏键盘
  static hideKeyboard({bool animation = true}) {
    ///键盘已经弹出
    if (_keyboardEntry != null) {
      _keyboardHeight = null;

      ///设置动画完成监控
      _pageKey.currentState.animationController.addStatusListener((status) {
        if (status == AnimationStatus.dismissed ||
            status == AnimationStatus.completed) {
          if (_keyboardEntry != null) {
            _keyboardEntry.remove();
            _keyboardEntry = null;
          }
        }
      });
      if (animation) {
        ///启用动画退出
        _pageKey.currentState.exitKeyboard();
      } else {
        _keyboardEntry.remove();
        _keyboardEntry = null;
      }
    }
    _pageKey = null;

    ///更新输入框位置
    KeyboardMediaQueryState queryState = _context
            .ancestorStateOfType(const TypeMatcher<KeyboardMediaQueryState>())
        as KeyboardMediaQueryState;
    queryState.update();
  }

  ///置空键盘配置
  static clearKeyboard() {
    _currentKeyboard = null;
    if (_keyboardController != null) {
      _keyboardController.dispose();
      _keyboardController = null;
    }
  }

  static sendPerformAction(TextInputAction action) {
    var callbackMethodCall = MethodCall("TextInputClient.performAction",
        [_keyboardController.client.connectionId, action.toString()]);
    BinaryMessages.handlePlatformMessage("flutter/textinput",
        _codec.encodeMethodCall(callbackMethodCall), (data) {});
  }
}

///键盘配置
class KeyboardConfig {
  ///键盘生成方法
  final KeyboardBuilder builder;

  ///获取键盘高度方法
  final GetKeyboardHeight getHeight;
  const KeyboardConfig({this.builder, this.getHeight});
}

///输入框属性解析类
class InputClient {
  final int connectionId;
  final TextInputConfiguration configuration;
  const InputClient({this.connectionId, this.configuration});

  factory InputClient.fromJSON(List<dynamic> encoded) {
    return InputClient(
        connectionId: encoded[0],
        configuration: TextInputConfiguration(
            inputType: SecurityTextInputType.fromJSON(encoded[1]['inputType']),
            obscureText: encoded[1]['obscureText'],
            autocorrect: encoded[1]['autocorrect'],
            actionLabel: encoded[1]['actionLabel'],
            inputAction: _toTextInputAction(encoded[1]['inputAction']),
            textCapitalization:
                _toTextCapitalization(encoded[1]['textCapitalization']),
            keyboardAppearance:
                _toBrightness(encoded[1]['keyboardAppearance'])));
  }

  static TextInputAction _toTextInputAction(String action) {
    switch (action) {
      case 'TextInputAction.none':
        return TextInputAction.none;
      case 'TextInputAction.unspecified':
        return TextInputAction.unspecified;
      case 'TextInputAction.go':
        return TextInputAction.go;
      case 'TextInputAction.search':
        return TextInputAction.search;
      case 'TextInputAction.send':
        return TextInputAction.send;
      case 'TextInputAction.next':
        return TextInputAction.next;
      case 'TextInputAction.previuos':
        return TextInputAction.previous;
      case 'TextInputAction.continue_action':
        return TextInputAction.continueAction;
      case 'TextInputAction.join':
        return TextInputAction.join;
      case 'TextInputAction.route':
        return TextInputAction.route;
      case 'TextInputAction.emergencyCall':
        return TextInputAction.emergencyCall;
      case 'TextInputAction.done':
        return TextInputAction.done;
      case 'TextInputAction.newline':
        return TextInputAction.newline;
    }
    throw FlutterError('Unknown text input action: $action');
  }

  static TextCapitalization _toTextCapitalization(String capitalization) {
    switch (capitalization) {
      case 'TextCapitalization.none':
        return TextCapitalization.none;
      case 'TextCapitalization.characters':
        return TextCapitalization.characters;
      case 'TextCapitalization.sentences':
        return TextCapitalization.sentences;
      case 'TextCapitalization.words':
        return TextCapitalization.words;
    }

    throw FlutterError('Unknown text capitalization: $capitalization');
  }

  static Brightness _toBrightness(String brightness) {
    switch (brightness) {
      case 'Brightness.dark':
        return Brightness.dark;
      case 'Brightness.light':
        return Brightness.light;
    }

    throw FlutterError('Unknown Brightness: $brightness');
  }
}

///自定义键盘输入类型
class SecurityTextInputType extends TextInputType {
  ///键盘类型名
  final String name;

  const SecurityTextInputType({this.name, bool signed, bool decimal})
      : super.numberWithOptions(signed: signed, decimal: decimal);

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'signed': signed,
      'decimal': decimal,
    };
  }

  factory SecurityTextInputType.fromJSON(Map<String, dynamic> encoded) {
    return SecurityTextInputType(
        name: encoded['name'],
        signed: encoded['signed'],
        decimal: encoded['decimal']);
  }
}

///键盘页（动画弹出）
class KeyboardPage extends StatefulWidget {
  ///具体键盘类
  final Widget child;

  ///键盘高度
  final double height;

  const KeyboardPage({this.child, this.height, Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => KeyboardPageState();
}

class KeyboardPageState extends State<KeyboardPage>
    with SingleTickerProviderStateMixin {
  /// 动画控制
  AnimationController animationController;

  /// 动画
  Animation<double> doubleAnimation;
  double bottom;

  @override
  void initState() {
    super.initState();
    animationController = new AnimationController(
        duration: new Duration(milliseconds: 100), vsync: this)
      ..addListener(() => setState(() {}));

    ///控制键盘滚动到键盘高度
    doubleAnimation = new Tween(begin: 0.0, end: widget.height)
        .animate(animationController)
          ..addListener(() => setState(() {}));

    ///启动支画
    animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    ///Overlay是一个Stack的widget，可以将overlay entry插入到overlay中，使独立的child窗口悬浮于其他widget之上。
    ///因为Overlay本身使用的是[Stack]布局，所以overlay entry可以使用[Positioned] 或者 [AnimatedPositioned]在overlay中定位自己的位置
    return Positioned(
        child: IntrinsicHeight(child: widget.child),
        bottom: (widget.height - doubleAnimation.value) * -1);
  }

  @override
  void dispose() {
    super.dispose();
    animationController.dispose();
  }

  void exitKeyboard() {
    animationController.reverse();
  }
}
