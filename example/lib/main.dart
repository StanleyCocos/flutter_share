import 'package:flutter/material.dart';
import 'package:fluttershare/fluttershare.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              FlutterShare.share(
                ShareModel(
                  platform: SharePlatform.Facebook,
                  // text: "https://www.100.com.tw/",
                  image: "https://www.baidu.com/img/bd_logo1.png",
//                  image:
//                  "https://cp4.100.com.tw/images/works/202004/15/api_1912317_1586915223_7O9RQuMFAV.jpg!c290x290-v2.webp",
//                image: "/data/user/0/com.addcn.fluttershare_example/cache/temp_650295255636641695.png",
                ),
                result: (state, msg) {
                  print("== state: $state == msg: $msg");
                },
              );
            },
            child: Text("Share"),
          ),
        ),
      ),
    );
  }
}
