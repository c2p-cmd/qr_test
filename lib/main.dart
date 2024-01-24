import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:pasteboard/pasteboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: "QR Generator",
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();
    final theme = CupertinoTheme.of(context).textTheme;
    final imageBytes = useState<Uint8List?>(null);
    final isBusy = useState(false);

    return CupertinoPageScaffold(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const Gap(10),
          Text(
            "QR Code Generator",
            style: theme.navLargeTitleTextStyle,
          ),
          const Gap(20),
          CupertinoTextField(
            placeholder: "Type something to generate QR for",
            controller: textController,
            expands: true,
            minLines: null,
            maxLines: null,
            onSubmitted: (textValue) {
              submit(
                context,
                textValue,
                imageBytes,
                isBusy,
                textController.clear,
              );
            },
            enabled: !isBusy.value,
          ),
          const Gap(30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Opacity(
                opacity: isBusy.value ? 0.5 : 1.0,
                child: CupertinoButton.filled(
                  child: const Text("Generate QR!"),
                  onPressed: () {
                    submit(
                      context,
                      textController.text,
                      imageBytes,
                      isBusy,
                      textController.clear,
                    );
                  },
                ),
              ),
              CupertinoButton.filled(
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Paste"),
                    Icon(Icons.paste_rounded),
                  ],
                ),
                onPressed: () async {
                  isBusy.value = true;
                  final image = await Pasteboard.image;
                  if (image == null) {
                    final text = await Pasteboard.text;
                    if (text != null) {
                      if (context.mounted) {
                        submit(
                          context,
                          text,
                          imageBytes,
                          isBusy,
                          () {},
                        );
                      }
                    }

                    isBusy.value = false;
                    return;
                  }
                  final encoded = base64Encode(image);
                  if (context.mounted) {
                    submit(
                      context,
                      encoded,
                      imageBytes,
                      isBusy,
                      () {},
                    );
                  }
                },
              ),
            ],
          ),
          const Gap(30),
          if (isBusy.value) const CupertinoActivityIndicator(),
          const Gap(30),
          AnimatedSwitcher(
            key: ValueKey(imageBytes.value),
            duration: const Duration(seconds: 1),
            child: qrWidget(context, imageBytes.value),
          ),
        ],
      ),
    );
  }

  Widget qrWidget(BuildContext context, Uint8List? imageBytes) {
    if (imageBytes == null) {
      return const SizedBox(
        height: 100,
      );
    }

    return CupertinoContextMenu(
      actions: [
        CupertinoButton.filled(
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Copy"),
              Icon(Icons.copy),
            ],
          ),
          onPressed: () {
            Pasteboard.writeImage(imageBytes).whenComplete(() {
              debugPrint("complete!");
            });
            Navigator.maybeOf(context)?.maybePop();
          },
        ),
      ],
      child: Image.memory(
        imageBytes,
        fit: BoxFit.fitHeight,
        height: 250,
      ),
    );
  }

  void submit(
    BuildContext context,
    String textValue,
    ValueNotifier<Uint8List?> imageBytes,
    ValueNotifier<bool> isBusy,
    void Function()? onDone,
  ) async {
    final url = Uri.parse(
      "https://chart.googleapis.com/chart?cht=qr&chs=500x500&chl=$textValue",
    );

    try {
      isBusy.value = true;
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw http.ClientException(
          response.reasonPhrase ?? response.statusCode.toString(),
        );
      }

      imageBytes.value = response.bodyBytes;
      isBusy.value = false;
      onDone?.call();
    } on Exception catch (e) {
      isBusy.value = false;
      onDone?.call();
      // ignore: use_build_context_synchronously
      showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text("Error!"),
            content: Text(e.toString()),
            actions: [
              CupertinoButton(
                child: const Text("Okay"),
                onPressed: () {
                  Navigator.maybeOf(context)?.maybePop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
