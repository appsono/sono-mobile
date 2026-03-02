import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rfw/formats.dart';
import 'package:rfw/rfw.dart';
import 'package:sono_extensions/sono_extensions.dart';

/// Renders an RFW-mode extensions widget tree
///
/// Loads the widget definition from [extensionDir]/[uiFile] (a text-format RFW file), 
/// builds a [DynamicContent] that Lua can update via sono.ui.setData,
/// and renders it with [RemoteWidget]
///
/// Widget events fired from the RFW tree are forwarded to the Lua hook
/// sono_onWidgetEvent(eventName, args)
class ExtensionRfwWidget extends StatefulWidget {
  const ExtensionRfwWidget({
    super.key,
    required this.runtime,
    required this.extensionDir,
    required this.uiFile,
  });

  final LuaRuntime runtime;
  final String extensionDir;
  final String uiFile;

  @override
  State<ExtensionRfwWidget> createState() => _ExtensionRfwWidgetState();
}

class _ExtensionRfwWidgetState extends State<ExtensionRfwWidget> {
  final Runtime _rfw = Runtime();
  late DynamicContent _content;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _content = DynamicContent();

    //wire Lua => DynamicContent updates
    widget.runtime.onUiDataChanged = (key, value) {
      if (!mounted) return;
      setState(() {
        _content.update(key, value ?? '');
      });
    };

    _loadRfwFile();
  }

  Future<void> _loadRfwFile() async {
    try {
      _rfw.update(
        const LibraryName(['core', 'widgets']),
        createCoreWidgets(),
      );
      _rfw.update(
        const LibraryName(['core', 'material']),
        createMaterialWidgets(),
      );

      final filePath = '${widget.extensionDir}/${widget.uiFile}';
      final source = await File(filePath).readAsString();
      _rfw.update(
        const LibraryName(['local']),
        parseLibraryFile(source),
      );

      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    widget.runtime.onUiDataChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Extension UI error:\n$_error',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }
    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4893)),
      );
    }
    return RemoteWidget(
      runtime: _rfw,
      data: _content,
      widget: const FullyQualifiedWidgetName(
        LibraryName(['local']),
        'root',
      ),
      onEvent: (String type, DynamicMap arguments) {
        if (!widget.runtime.isActive) return;
        try {
          widget.runtime.callHook('onWidgetEvent', [type, arguments]);
        } catch (_) {}
      },
    );
  }
}
