# security_keyboard

A flutter security keyboard for multiple TextField and automatically positioned to the TextField position.

### Add dependency


```yaml
dependencies:
  security_keyboard: ^1.0.2
```


## Examples

## Step1
Write a personalized keyboard based on project needs

```dart
typedef KeyboardSwitch = Function(SecurityKeyboardType type);

enum SecurityKeyboardType {
  text
}

class SecurityKeyboard extends StatefulWidget {
  ///用于控制键盘输出的Controller
  final KeyboardController controller;

  ///键盘类型,默认文本
  final SecurityKeyboardType keyboardType;


  const SecurityKeyboard({this.controller, this.keyboardType});

  ///文本输入类型
  static SecurityTextInputType text =
      SecurityKeyboard._inputKeyboard(SecurityKeyboardType.text);

  ///初始化键盘类型，返回输入框类型
  static SecurityTextInputType _inputKeyboard(
      SecurityKeyboardType securityKeyboardType) {
    ///设置输入框类型对应的键盘
    String inputType = securityKeyboardType.toString();
    SecurityTextInputType securityTextInputType = SecurityTextInputType(name: inputType);
    KeyboardManager.addKeyboard(
      securityTextInputType,
      KeyboardConfig(
        builder: (context, controller) {
          return SecurityKeyboard(
            controller: controller,
            keyboardType: securityKeyboardType,
          );
        },
        getHeight: () {
          return SecurityKeyboard.getHeight(securityKeyboardType);
        },
      ),
    );

    return securityTextInputType;
  }

  ///键盘类型
  SecurityKeyboardType get _keyboardType => keyboardType;

  ///编写获取高度的方法
  static double getHeight(SecurityKeyboardType securityKeyboardType) {
    return 232;
  }


  @override
  _SecurityKeyboardState createState() => _SecurityKeyboardState();
}

class _SecurityKeyboardState extends State<SecurityKeyboard> {
  ///当前键盘类型
  SecurityKeyboardType currentKeyboardType;

  @override
  void initState() {
    super.initState();
    currentKeyboardType = widget._keyboardType;
  }

  @override
  Widget build(BuildContext context) {
    Widget keyboard;
   
    return keyboard;
  }
}

```

## Step2
Add the following code to the page where you want to use the secure keyboard.

```dart
class PasswordVerify extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ///WidgetsApp或者MaterialApp,Flutter会自动默认创建一个Navigator
    ///用于键盘弹出的时候页面可以滚动到输入框的位置
    return WillPopScope(
      child: KeyboardMediaQuery(
        child: Builder(builder: (ctx) {
          ///初始化键盘监听并且传递当前页面的context
          KeyboardManager.init(ctx);
          return Scaffold(
            appBar: AppBar(
              title: Text('验证登录密码'),
              brightness: Brightness.light,
            ),
            body: PasswordWidget(),
          );
        }),
      ),
      onWillPop: _requestPop,
    );
  }

  ///物理返回
  Future<bool> _requestPop() {
    bool b = true;
    if (KeyboardManager.isShowKeyboard) {
      KeyboardManager.hideKeyboard();
      b = false;
    }
    return Future.value(b);
  }
}
```


## Step3
Set custom security keyboard type in the TextField keyboardType.
Just Pass the inputType written in Step1 as you normally would set the keyboard input type.
```dart
TextField(
   ...
   keyboardType: SecurityKeyboard.text,
   ...
 )
```