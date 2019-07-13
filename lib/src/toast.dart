import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'basis.dart';
import 'key_board_safe_area.dart';
import 'toast_navigator_observer.dart';

part 'bot_toast_manager.dart';

part 'toast_widget.dart';

void _safeRun(void Function() callback) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    callback();
  });
  SchedulerBinding.instance.scheduleFrame();
}

/*区域图
  _________________________________
|          MainContent            |
|                                 |
|                                 |
|      ___________________        |
|     |                   |       |
|     |    ToastContent   |       |
|     |___________________|       |
|_________________________________|
 */
///todo 添加到注意事项
///不要在调用[ToastBuilder]方法生成widget时,
///该确保生成的Widget背景不会吸收点击事件
///例如[Scaffold],[Material]都会默认占满整个父空间,
///并且会吸收事件(就算透明也是这种情况),具体例子可看[material.dart->_RenderInkFeatures class->hitTestSelf method]
///如果真的要生成,可以考虑使用[IgnorePointer].
///如果没有遵守规则,将会时某些功能失效例如[allowClick]功能就会失效
class BotToast {
  static GlobalKey<_BotToastManagerState> _managerState;
  static const String textKey = "_textKey";
  static const String notificationKey = "_notificationKey";
  static const String loadKey = "_loadKey";
  static const String attachedKey = "_attachedKey";
  static const String defaultKey = "_defaultKey";

  static final Map<String, List<CancelFunc>> cacheCancelFunc = {
    textKey: [],
    notificationKey: [],
    loadKey: [],
    attachedKey: [],
    defaultKey: [],
  };

  ///此方法暂时不能多次初始化!
  static init(BuildContext context) {
    assert(BotToastNavigatorObserver.debugInitialization, """
    请初始化BotToastNavigatorObserver
    Please initialize!
    Example:
    MaterialApp(
      title: 'BotToast Demo',
      navigatorObservers: [BotToastNavigatorObserver()],
      home: BotToastInit(child: EnterPage()),
    );
    """);
    _safeRun(() {
      assert(_managerState == null, "不允许初始化多次!");
      Overlay.of(context).insert(OverlayEntry(builder: (_) {
        return _BotToastManager(
          key: _managerState,
        );
      }));
      _managerState = GlobalKey<_BotToastManagerState>();
    });
  }

  ///显示简单的通知Toast
  ///
  ///[title] 标题
  ///[subTitle] 副标题
  ///[closeIcon] 关闭按钮的图标
  ///[enableSlideOff] 是否能滑动删除
  ///[hideCloseButton] 是否隐藏关闭按钮
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  ///[onlyOne] 请看[showEnhancedWidget.onlyOne]
  static CancelFunc showSimpleNotification(
      {@required String title,
      String subTitle,
      Icon closeIcon,
      Duration duration = const Duration(seconds: 2),
      bool enableSlideOff = true,
      bool hideCloseButton = false,
      bool crossPage = true,
      bool onlyOne = true}) {
    return showNotification(
        duration: duration,
        enableSlideOff: enableSlideOff,
        onlyOne: onlyOne,
        crossPage: crossPage,
        title: (_) => Text(title),
        subtitle: subTitle == null ? null : (_) => Text(subTitle),
        trailing: hideCloseButton?null:(cancel) => IconButton(
            icon: closeIcon ?? Icon(Icons.cancel), onPressed: cancel));
  }

  ///显示一个标准的通知Toast
  ///
  ///[leading]_[title]_[subtitle]_[trailing]_[contentPadding] 请看[ListTile]
  ///[enableSlideOff] 是否能滑动删除
  ///[hideCloseButton] 是否有incl
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[onlyOne] 请看[showEnhancedWidget.onlyOne]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  static CancelFunc showNotification(
      {ToastBuilder leading,
      ToastBuilder title,
      ToastBuilder subtitle,
      ToastBuilder trailing,
      Duration duration = const Duration(seconds: 2),
      EdgeInsetsGeometry contentPadding,
      bool enableSlideOff = true,
      bool crossPage = true,
      bool onlyOne = true}) {
    return showCustomNotification(
        enableSlideOff: enableSlideOff,
        onlyOne: onlyOne,
        crossPage: crossPage,
        duration: duration,
        toastBuilder: (cancel) {
          return Card(
            child: ListTile(
                contentPadding: contentPadding,
                leading: leading?.call(cancel),
                title: title?.call(cancel),
                subtitle: subtitle?.call(cancel),
                trailing: trailing?.call(cancel)),
          );
        });
  }

  ///显示一个自定义的通知Toast
  ///
  ///[toastBuilder] 生成需要显示的Widget的builder函数
  ///[enableSlideOff] 是否能滑动删除
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[onlyOne] 请看[showEnhancedWidget.onlyOne]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  static CancelFunc showCustomNotification(
      {@required ToastBuilder toastBuilder,
      Duration duration = const Duration(seconds: 2),
      bool enableSlideOff = true,
      bool crossPage = true,
      bool onlyOne = true}) {
    final key = GlobalKey<NormalAnimationState>();

    CancelFunc cancelAnimationFunc;

    CancelFunc cancelFunc = showEnhancedWidget(
        crossPage: crossPage,
        allowClick: true,
        clickClose: false,
        ignoreContentClick: false,
        onlyOne: onlyOne,
        duration: duration,
        closeFunc: () => cancelAnimationFunc(),
        toastBuilder: (cancelFunc) => NormalAnimation(
              key: key,
              reverse: true,
              child: _NotificationToast(
                  child: toastBuilder(cancelAnimationFunc),
                  slideOffFunc: enableSlideOff ? cancelFunc : null),
            ),
        groupKey: notificationKey);

    cancelAnimationFunc = () async {
      await key.currentState?.hide();
      cancelFunc();
    };

    return cancelAnimationFunc;
  }

  ///显示一个标准文本Toast
  ///
  ///[text] 需要显示的文本
  ///[backgroundColor] 请看[showEnhancedWidget.backgroundColor]
  ///[contentColor] ToastContent区域背景颜色
  ///[borderRadius] ToastContent区域圆角
  ///[textStyle] 字体样式
  ///[align] ToastContent区域在MainContent区域的对齐
  ///[contentPadding] ToastContent区域的内补
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[onlyOne] 请看[showEnhancedWidget.onlyOne]
  ///[clickClose] 请看[showEnhancedWidget.clickClose]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  static CancelFunc showText(
      {@required String text,
      Color backgroundColor = Colors.transparent,
      Color contentColor = Colors.black54,
      BorderRadiusGeometry borderRadius =
          const BorderRadius.all(Radius.circular(8)),
      TextStyle textStyle = const TextStyle(fontSize: 17, color: Colors.white),
      AlignmentGeometry align = const Alignment(0, 0.8),
      EdgeInsetsGeometry contentPadding =
          const EdgeInsets.only(left: 14, right: 14, top: 5, bottom: 7),
      Duration duration = const Duration(seconds: 2),
      bool clickClose = false,
      bool crossPage = true,
      bool onlyOne = false}) {
    return showCustomText(
        duration: duration,
        crossPage: crossPage,
        backgroundColor: backgroundColor,
        clickClose: clickClose,
        onlyOne: onlyOne,
        toastBuilder: (_) => _TextToast(
              contentPadding: contentPadding,
              contentColor: contentColor,
              borderRadius: borderRadius,
              textStyle: textStyle,
              align: align,
              text: text,
            ));
  }

  ///显示一个自定义的文本Toast
  ///
  ///[toastBuilder] 生成需要显示的Widget的builder函数
  ///[ignoreContentClick] 请看[showEnhancedWidget.ignoreContentClick]
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[onlyOne] 请看[showEnhancedWidget.onlyOne]
  ///[clickClose] 请看[showEnhancedWidget.clickClose]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  ///[backgroundColor] 请看[showEnhancedWidget.backgroundColor]
  static CancelFunc showCustomText(
      {@required ToastBuilder toastBuilder,
      Color backgroundColor = Colors.transparent,
      Duration duration = const Duration(seconds: 2),
      bool crossPage = true,
      bool clickClose = false,
      bool ignoreContentClick = false,
      bool onlyOne = false}) {
    final key = GlobalKey<NormalAnimationState>();

    CancelFunc cancelAnimationFunc;

    CancelFunc cancelFunc = showEnhancedWidget(
      groupKey: textKey,
      closeFunc: () => cancelAnimationFunc(),
      clickClose: clickClose,
      allowClick: true,
      onlyOne: onlyOne,
      crossPage: crossPage,
      ignoreContentClick: ignoreContentClick,
      backgroundColor: backgroundColor,
      duration: duration,
      toastBuilder: (_) => SafeArea(
              child: NormalAnimation(
            key: key,
            child: toastBuilder(cancelAnimationFunc),
          )),
    );

    //有动画的方式关闭
    cancelAnimationFunc = () async {
      await key.currentState?.hide();
      cancelFunc();
    };

    return cancelAnimationFunc;
  }

  ///显示一个标准的加载Toast
  ///
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[allowClick] 请看[showEnhancedWidget.allowClick]
  ///[clickClose] 请看[showEnhancedWidget.clickClose]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  ///[backgroundColor] 请看[showEnhancedWidget.backgroundColor]
  static CancelFunc showLoading({
    bool crossPage = true,
    bool clickClose = false,
    bool allowClick = false,
    Duration duration,
    Color backgroundColor = Colors.black26,
  }) {
    return showCustomLoading(
        loadWidget: (_) => _LoadingWidget(),
        clickClose: clickClose,
        allowClick: allowClick,
        crossPage: crossPage,
        ignoreContentClick: true,
        duration: duration,
        backgroundColor: backgroundColor);
  }

  ///显示一个自定义的加载Toast
  ///
  ///[loadWidget] 生成需要显示的Widget的builder函数
  ///[ignoreContentClick] 请看[showEnhancedWidget.ignoreContentClick]
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[onlyOne] 请看[showEnhancedWidget.onlyOne]
  ///[allowClick] 请看[showEnhancedWidget.allowClick]
  ///[clickClose] 请看[showEnhancedWidget.clickClose]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  ///[backgroundColor] 请看[showEnhancedWidget.backgroundColor]
  static CancelFunc showCustomLoading({
    @required ToastBuilder loadWidget,
    bool clickClose = false,
    bool allowClick = false,
    bool ignoreContentClick = true,
    bool crossPage = false,
    Duration duration,
    Color backgroundColor = Colors.black26,
  }) {
    assert(loadWidget != null, "loadWidget not null");

    final key = GlobalKey<FadeAnimationState>();

    CancelFunc cancelAnimationFunc;

    CancelFunc cancelFunc = showEnhancedWidget(
        groupKey: loadKey,
        toastBuilder: (_) => SafeArea(child: loadWidget(cancelAnimationFunc)),
        warpWidget: (child) => FadeAnimation(
              key: key,
              child: child,
            ),
        clickClose: clickClose,
        allowClick: allowClick,
        crossPage: crossPage,
        ignoreContentClick: ignoreContentClick,
        onlyOne: false,
        duration: duration,
        closeFunc: () => cancelAnimationFunc(),
        backgroundColor: backgroundColor);

    cancelAnimationFunc = () async {
      await key.currentState?.hide();
      cancelFunc();
    };

    return cancelAnimationFunc;
  }

  ///此方法一般使用在dispose里面,防止因为开发人员没有主动去关闭,或者是请求api时的出现异常
  ///导致CancelFunc方法没有执行到等等,导致用户点击不了app
  static void closeAllLoading() {
    //以此方式移除将不会触发关闭动画
    removeAll(loadKey);
  }

  ///显示一个定位Toast
  ///该方法可以在某个Widget(一般是Button)或者给定一个offset周围显示
  ///
  ///[toastBuilder] 生成需要显示的Widget的builder函数
  ///[targetContext] 目标Widget(一般是一个按钮),使用上一般会使用[Builder]包裹,来获取到BuildContext
  ///[target] 目标[Offset],该偏移是以屏幕左上角为原点来计算的
  ///[target]和[targetContext] 只能二选一
  ///[verticalOffset]  垂直偏移跟[preferDirection]有关,根据不同的方向会作用在不用的方向上
  ///[preferDirection] 偏好方向,如果在空间允许的情况下,会偏向显示在那边
  ///[duration] 请看[showEnhancedWidget.duration]
  ///[ignoreContentClick] 请看[showEnhancedWidget.ignoreContentClick]
  ///[onlyOne] 请看[showEnhancedWidget.onlyOne]
  ///[allowClick] 请看[showEnhancedWidget.allowClick]
  ///[crossPage] 请看[showEnhancedWidget.crossPage]
  static CancelFunc showAttachedWidget({
    @required ToastBuilder attachedWidget,
    BuildContext targetContext,
    Color backgroundColor = Colors.transparent,
    Offset target,
    double verticalOffset = 24,
    Duration duration,
    PreferDirection preferDirection,
    bool ignoreContentClick = false,
    bool onlyOne = false,
    bool allowClick = true,
    bool crossPage = false,
  }) {
    assert(!(targetContext != null && target != null),
        "targetContext and target cannot coexist");
    assert(targetContext != null || target != null,
        "targetContext and target must exist one");

    if (target == null) {
      RenderObject renderObject = targetContext.findRenderObject();
      if (renderObject is RenderBox) {
        target =
            renderObject.localToGlobal(renderObject.size.center(Offset.zero));
      } else {
        throw Exception(
            "context.findRenderObject() return result must be RenderBox class");
      }
    }
    GlobalKey<FadeAnimationState> key = GlobalKey<FadeAnimationState>();

    CancelFunc cancelAnimationFunc;

    CancelFunc cancelFunc = showEnhancedWidget(
        allowClick: allowClick,
        clickClose: true,
        groupKey: attachedKey,
        crossPage: crossPage,
        onlyOne: onlyOne,
        backgroundColor: backgroundColor,
        ignoreContentClick: ignoreContentClick,
        closeFunc: () => cancelAnimationFunc(),
        warpWidget: (widget) => FadeAnimation(
              child: widget,
              key: key,
              duration: Duration(milliseconds: 150),
            ),
        duration: duration,
        toastBuilder: (_) => CustomSingleChildLayout(
              delegate: PositionDelegate(
                  target: target,
                  verticalOffset: verticalOffset ?? 0,
                  preferDirection: preferDirection),
              child: attachedWidget(cancelAnimationFunc),
            ));

    cancelAnimationFunc = () async {
      await key.currentState?.hide();
      cancelFunc();
    };

    return cancelAnimationFunc;
  }

  /*区域图
    _________________________________
   |          MainContent            |
   |                      <----------------------allowClick
   |                      <----------------------clickClose
   |      ___________________        |
   |     |                   |       |
   |     |    ToastContent   |       |
   |     |                <----------------------ignoreContentClick
   |     |___________________|       |
   |_________________________________|
   */

  ///显示一个增强Toast,该方法可以让Toast自带很多特性,例如定时关闭,点击屏幕自动关闭,离开当前Route关闭等等
  ///核心方法,详情使用请看:
  ///[BotToast.showCustomNotification]
  ///[BotToast.showCustomText]
  ///[BotToast.showCustomLoading]
  ///[BotToast.showAttachedWidget]
  ///
  ///[toastBuilder] 生成需要显示的Widget的builder函数
  ///[key] 代表此Toast的一个凭证,凭此key可以删除当前key所定义的Widget,[remove]
  ///[groupKey] 代表分组的key,主要用于[removeAll]和[remove]
  ///
  ///[crossPage] 跨页面显示,如果为true,则该Toast会跨越多个Route显示,
  ///如果为false则在当前Route发生变化时,会自动关闭该Toast
  ///
  ///[allowClick] 是否在该Toast显示时,能否正常点击触发事件
  ///[clickClose] 是否在点击屏幕触发事件时自动关闭该Toast
  ///
  ///[ignoreContentClick] 是否忽视ToastContext区域
  ///这个参数如果为true时,用户点击该ToastContext区域时,用户可以的点击事件可以正常到达到Page上
  ///换一句话说就是透明的(即时Toast背景颜色不是透明),如果为false,则情况反之
  ///
  ///[onlyOne] 该分组内是否在同一时间里只存在一个Toast,区分是哪一个组是按照[groupKey]来区分的
  ///
  ///[clickClose] 该函数参数主要目的使一个自动关闭功能(定时关闭,点击关闭)
  ///触发关闭前调用[AnimationController]来启动并等待动画后再关闭
  ///
  ///[backgroundColor]  MainContent区域的背景颜色
  ///[warpWidget] 一个wrap函数,可以用来warp MainContent区域,例如[showCustomLoading]就包裹了一个动画
  ///让MainContent区域也具有动画
  ///
  ///[duration] 持续时间,如果为null则不会去定时关闭,如果不为null则在到达指定时间时自动关闭
  static CancelFunc showEnhancedWidget(
      {@required ToastBuilder toastBuilder,
      UniqueKey key,
      String groupKey,
      bool crossPage = true,
      bool allowClick = true,
      bool clickClose = false,
      bool ignoreContentClick = false,
      bool onlyOne = false,
      CancelFunc closeFunc,
      Color backgroundColor = Colors.transparent,
      WrapWidget warpWidget,
      Duration duration}) {
    //由于dismissFunc一开始是为空的,所以在赋值之前需要在闭包里使用
    CancelFunc dismissFunc;

    //onlyOne 功能
    final List<CancelFunc> cache =
        (cacheCancelFunc[groupKey ?? defaultKey] ??= []);
    if (onlyOne) {
      final clone = cache.toList();
      cache.clear();
      clone.forEach((cancel) {
        cancel();
      });
    }
    VoidCallback rememberFunc = () => dismissFunc();
    cache.add(rememberFunc);

    //定时功能
    Timer timer;
    if (duration != null) {
      timer = Timer(duration, () {
        dismissFunc();
        timer = null;
      });
    }

    CancelFunc cancelFunc = showWidget(
        groupKey: groupKey,
        key: key,
        toastBuilder: (cancel) {
          return KeyBoardSafeArea(
            child: ProxyDispose(disposeCallback: () {
              cache.remove(rememberFunc);
              timer?.cancel();
            }, child: Builder(
              builder: (BuildContext context) {
                TextStyle textStyle = Theme.of(context).textTheme.body1;
                Widget child = DefaultTextStyle(
                    style: textStyle,
                    child: Stack(
                      children: <Widget>[
                        Listener(
                          onPointerDown:
                              clickClose ? (_) => dismissFunc() : null,
                          behavior: allowClick
                              ? HitTestBehavior.translucent
                              : HitTestBehavior.opaque,
                          child: SizedBox.expand(),
                        ),
                        IgnorePointer(
                          child: Container(color: backgroundColor),
                        ),
                        IgnorePointer(
                          ignoring: ignoreContentClick,
                          child: toastBuilder(cancel),
                        )
                      ],
                    ));
                return warpWidget != null ? warpWidget(child) : child;
              },
            )),
          );
        });

    dismissFunc = closeFunc ?? cancelFunc;

    if (!crossPage) {
      BotToastNavigatorObserver.instance.runOnce(cancelFunc);
    }

    return cancelFunc;
  }

  ///显示一个Widget在屏幕上,该Widget可以跨多个页面存在
  ///
  ///[toastBuilder] 生成需要显示的Widget的builder函数
  ///[key] 代表此Toast的一个凭证,凭此key可以删除当前key所定义的Widget,[remove]
  ///[groupKey] 代表分组的key,主要用于[removeAll]和[remove]
  ///[CancelFunc] 关闭函数,主动调用将会关闭此Toast
  ///这是个核心方法
  static CancelFunc showWidget(
      {@required ToastBuilder toastBuilder, UniqueKey key, String groupKey}) {
    assert(toastBuilder != null);
    final gk = groupKey ?? defaultKey;
    final uniqueKey = key ?? UniqueKey();
    final CancelFunc cancelFunc = () {
      remove(uniqueKey, gk);
    };
    _safeRun(() {
      /*
      如果currentState为空说明此时BotToast还没初始化完成,此时的状态是处理showWidget和init方法都是是在同一帧里,
      因此要把showWidget方法放在下一帧处理
      */
      if (_managerState.currentState == null) {
        _safeRun(() {
          _managerState.currentState
              .insert(gk, uniqueKey, toastBuilder(cancelFunc));
        });
      } else {
        _managerState.currentState
            .insert(gk, uniqueKey, toastBuilder(cancelFunc));
      }
    });
    return cancelFunc;
  }

  static void remove(UniqueKey key, [String groupKey]) {
    _safeRun(() {
      _managerState.currentState.remove(groupKey ?? defaultKey, key);
    });
  }

  static void removeAll([String groupKey]) {
    _safeRun(() {
      _managerState.currentState.removeAll(groupKey ?? defaultKey);
    });
  }

  static void cleanAll() {
    _safeRun(() {
      _managerState.currentState.cleanAll();
    });
  }
}
