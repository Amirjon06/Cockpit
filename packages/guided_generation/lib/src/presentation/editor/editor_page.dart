import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../formatters/citation_formatter.dart';

class GuidedEditorPage extends StatefulWidget {
  const GuidedEditorPage({super.key});

  @override
  State<GuidedEditorPage> createState() => _GuidedEditorPageState();
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) => false;
}

class _GuidedEditorPageState extends State<GuidedEditorPage> {
  final QuillController _controller = QuillController.basic();
  final CitationFormatter _formatter = const CitationFormatter();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController(
    text: 'Untitled document',
  );
  final MenuController _citationMenuController = MenuController();

  TextSelection _editorSelection = const TextSelection.collapsed(offset: 0);
  TextSelection? _savedSelection;
  String _displayFont = 'Arial';
  bool _sidebarOpen = true;

  CitationStyle _citationStyle = CitationStyle.apa;
  bool _saving = false;
  bool _saved = true;
  double _zoom = 1.0;

  final List<CitationSource> _sources = const [
    CitationSource(
      id: '1',
      author: 'Smith, Jordan',
      title: 'Artificial Intelligence and Modern Education',
      publisher: 'Academic Press',
      year: '2025',
      url: 'https://example.com/ai-education',
    ),
    CitationSource(
      id: '2',
      author: 'Lee, Morgan',
      title: 'Technology in the Classroom',
      publisher: 'Education Review',
      year: '2024',
      url: 'https://example.com/classroom-technology',
    ),
  ];

  @override
  void initState() {
    super.initState();

    final first = _formatter.inlineCitation(
      _sources[0],
      _citationStyle,
      index: 1,
    );
    final second = _formatter.inlineCitation(
      _sources[1],
      _citationStyle,
      index: 2,
    );
    final references = _formatter.bibliography(_sources, _citationStyle);

    _controller.document.insert(
      0,
      'Artificial Intelligence in Education\n\n'
      'Artificial intelligence is changing how students learn and how '
      'educators design learning experiences. Adaptive systems can provide '
      'students with more personalized support while reducing repetitive '
      'work for instructors $first.\n\n'
      'The technology also introduces questions about accuracy, access, '
      'privacy, and the appropriate role of automation in education $second.'
      '\n\nReferences\n\n${references.join('\n\n')}\n',
    );

    _forceDocumentBlack();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _forceDocumentBlack();
    });

    _controller.addListener(_handleDocumentChange);
    _controller.onSelectionChanged = (selection) {
      if (selection.isValid) {
        _editorSelection = selection;

        if (!selection.isCollapsed) {
          _savedSelection = selection;
        } else if (_focusNode.hasFocus) {
          _savedSelection = null;
        }

        if (_focusNode.hasFocus) {
          final font = _controller
              .getSelectionStyle()
              .attributes[Attribute.font.key]
              ?.value
              ?.toString();

          _displayFont = font ?? 'Arial';
        }
      }

      if (mounted) setState(() {});
    };
  }

  void _forceDocumentBlack() {
    final length = _controller.document.length - 1;
    if (length <= 0) return;

    _controller.formatText(0, length, const ColorAttribute('#000000'));
  }

  void _handleDocumentChange() {
    if (_saved && mounted) {
      setState(() => _saved = false);
    }
  }

  int get _wordCount {
    final text = _controller.document.toPlainText().trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  int get _characterCount {
    return _controller.document.toPlainText().trim().length;
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;

    setState(() {
      _saving = false;
      _saved = true;
    });
  }

  void _changeCitationStyle(CitationStyle? style) {
    if (style == null || style == _citationStyle) return;

    final oldStyle = _citationStyle;
    var text = _controller.document.toPlainText();
    const referencesMarker = 'References\n\n';

    var bodyEnd = text.indexOf(referencesMarker);
    if (bodyEnd < 0) {
      bodyEnd = text.length;
    }

    for (var i = 0; i < _sources.length; i++) {
      final source = _sources[i];

      final oldInline = _formatter.inlineCitation(
        source,
        oldStyle,
        index: i + 1,
      );

      final newInline = _formatter.inlineCitation(source, style, index: i + 1);

      if (oldInline == newInline) continue;

      var searchFrom = 0;

      while (true) {
        text = _controller.document.toPlainText();
        final index = text.indexOf(oldInline, searchFrom);

        if (index < 0 || index >= bodyEnd) break;

        _controller.replaceText(
          index,
          oldInline.length,
          newInline,
          TextSelection.collapsed(offset: index + newInline.length),
        );

        bodyEnd += newInline.length - oldInline.length;
        searchFrom = index + newInline.length;
      }
    }

    text = _controller.document.toPlainText();
    final markerIndex = text.indexOf(referencesMarker);

    if (markerIndex >= 0) {
      final referencesStart = markerIndex + referencesMarker.length;
      final entries = _formatter.bibliography(_sources, style);
      final replacement = '${entries.join('\n\n')}\n';

      _controller.replaceText(
        referencesStart,
        text.length - referencesStart,
        replacement,
        TextSelection.collapsed(offset: referencesStart + replacement.length),
      );
    }

    _forceDocumentBlack();
    _savedSelection = null;

    setState(() {
      _citationStyle = style;
      _saved = false;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleDocumentChange);
    _titleController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11151B),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildEditor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    const red = Color(0xFFEF233C);
    const muted = Color(0xFFA99F91);

    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          color: const Color(0xFF080808),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(6),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child: Text(
                      '‹',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'assets/octopilot/OCTOPILOT.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(-8, 0),
                    child: SizedBox(
                      width: 185,
                      height: 36,
                      child: Image.asset(
                        'assets/octopilot/logoText.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Container(width: 1, height: 28, color: Colors.white12),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guided Generation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$_wordCount words',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!_saved) ...[
                const Text(
                  'Unsaved',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(width: 14),
              ],
              SizedBox(
                height: 34,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _saving ? 'Saving...' : 'Save',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 55,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            border: Border(bottom: BorderSide(color: Color(0xFF24211D))),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStep('WRITING STYLE', past: true),
                    _stepDivider(true),
                    _buildStep('INSTRUCTIONS', past: true),
                    _stepDivider(true),
                    _buildStep('OUTLINES', past: true),
                    _stepDivider(true),
                    _buildStep('CONFIGURATION', past: true),
                    _stepDivider(true),
                    _buildStep('FORMAT', past: true),
                    _stepDivider(true),
                    _buildStep('GENERATION', past: true),
                    _stepDivider(true),
                    _buildStep('PREVIEW', past: true),
                    _stepDivider(true),
                    _buildStep('HUMANIZER', past: true),
                    _stepDivider(true),
                    _buildStep('EDITOR', active: true),
                    _stepDivider(false),
                    _buildStep('EXPORT'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'WRITING MODE: GUIDED GENERATION',
                style: TextStyle(
                  color: Color(0xFFFACC15),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 3,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          color: const Color(0xFF151515),
          child: FractionallySizedBox(
            widthFactor: 0.9,
            child: Container(
              decoration: BoxDecoration(
                color: red,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(color: red.withValues(alpha: 0.45), blurRadius: 7),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String label, {bool active = false, bool past = false}) {
    final color = active
        ? const Color(0xFFEF4444)
        : past
        ? const Color(0xFF8A2D2D)
        : Colors.white24;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: active ? 10.5 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _stepDivider(bool past) {
    return Text(
      '>>>',
      style: TextStyle(
        color: past
            ? const Color(0xFF652727)
            : Colors.white.withValues(alpha: 0.08),
        fontSize: 8,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  TextSelection get _selectionForFormatting {
    return _savedSelection ?? _editorSelection;
  }

  void _restoreFormattingSelection(TextSelection selection) {
    _controller.updateSelection(selection, ChangeSource.local);

    _editorSelection = selection;

    if (!selection.isCollapsed) {
      _savedSelection = selection;
    }
  }

  void _toggleInlineFormat(Attribute attribute) {
    final selection = _selectionForFormatting;

    _focusNode.requestFocus();
    _controller.updateSelection(selection, ChangeSource.local);

    final current = _controller.getSelectionStyle().attributes[attribute.key];

    final next = current == null ? attribute : Attribute.clone(attribute, null);

    _controller.formatText(
      selection.start,
      selection.end - selection.start,
      next,
    );

    _restoreFormattingSelection(selection);
    setState(() {});
  }

  void _applyFormat(Attribute attribute) {
    final selection = _selectionForFormatting;

    _focusNode.requestFocus();

    _controller.formatText(
      selection.start,
      selection.end - selection.start,
      attribute,
    );

    _restoreFormattingSelection(selection);
    setState(() {});
  }

  void _applyFont(String font) {
    final selection = _selectionForFormatting;

    if (!selection.isValid) return;

    _controller.updateSelection(selection, ChangeSource.local);

    _controller.formatSelection(
      Attribute.fromKeyValue(Attribute.font.key, font),
    );

    _editorSelection = selection;

    if (!selection.isCollapsed) {
      _savedSelection = selection;
    }

    setState(() {
      _displayFont = font;
      _saved = false;
    });
  }

  void _indentSelection(bool increase) {
    final selection = _selectionForFormatting;

    _focusNode.requestFocus();
    _controller.updateSelection(selection, ChangeSource.local);

    _controller.indentSelection(increase);

    _restoreFormattingSelection(selection);
    setState(() {});
  }

  bool _formatActive(String key) {
    return _controller.getSelectionStyle().attributes.containsKey(key);
  }

  Widget _toolbarButton({
    required Widget child,
    required String tooltip,
    required VoidCallback onPressed,
    bool active = false,
    double width = 30,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0x38EA4335) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _toolbarLabel(
    String text, {
    FontWeight? weight,
    FontStyle? style,
    TextDecoration? decoration,
    double size = 14,
  }) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFFF3F4F6),
        fontSize: size,
        fontWeight: weight,
        fontStyle: style,
        decoration: decoration,
      ),
    );
  }

  Widget _toolbarDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: const Color(0xFF3A3F47),
    );
  }

  MenuStyle _toolbarMenuStyle(double width) {
    return MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(Color(0xFF171A1F)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(8),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
      minimumSize: WidgetStatePropertyAll(Size(width, 0)),
      maximumSize: WidgetStatePropertyAll(Size(width, 250)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF3B4048)),
        ),
      ),
    );
  }

  Widget _menuTrigger(
    String label, {
    required double width,
    required MenuController controller,
  }) {
    return InkWell(
      onTap: () {
        if (controller.isOpen) {
          controller.close();
        } else {
          controller.open();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: width,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            const CustomPaint(size: Size(8, 5), painter: _ChevronPainter()),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattingToolbar(BuildContext context) {
    final style = _controller.getSelectionStyle().attributes;

    return Container(
      height: 46,
      color: const Color(0xFF11151B),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pageWidth = 816 * _zoom;
          final availableWidth = constraints.maxWidth > 24
              ? constraints.maxWidth - 24
              : constraints.maxWidth;

          final desiredToolbarWidth = pageWidth + 320;

          final toolbarWidth = desiredToolbarWidth < availableWidth
              ? desiredToolbarWidth
              : availableWidth;

          final side = (constraints.maxWidth - toolbarWidth) / 2;

          return Padding(
            padding: EdgeInsets.only(left: side, right: side, top: 4),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1B2028),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(bottom: BorderSide(color: Color(0xFF2F353F))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _toolbarButton(
                      tooltip: 'Undo',
                      onPressed: () {
                        _controller.undo();
                        _focusNode.requestFocus();
                        setState(() {});
                      },
                      child: _toolbarLabel('↶', size: 18),
                    ),
                    _toolbarButton(
                      tooltip: 'Redo',
                      onPressed: () {
                        _controller.redo();
                        _focusNode.requestFocus();
                        setState(() {});
                      },
                      child: _toolbarLabel('↷', size: 18),
                    ),

                    _toolbarDivider(context),

                    _toolbarButton(
                      tooltip: 'Zoom out',
                      onPressed: () {
                        setState(() {
                          _zoom = (_zoom - 0.1).clamp(0.5, 2.0);
                        });
                      },
                      width: 28,
                      child: _toolbarLabel('−', size: 18),
                    ),

                    MenuAnchor(
                      style: _toolbarMenuStyle(82),
                      menuChildren: [
                        for (final zoom in const [
                          50,
                          75,
                          90,
                          100,
                          110,
                          125,
                          150,
                          200,
                        ])
                          MenuItemButton(
                            onPressed: () {
                              setState(() {
                                _zoom = zoom / 100;
                              });
                            },
                            child: Text('$zoom%'),
                          ),
                      ],
                      builder: (context, controller, child) {
                        return _menuTrigger(
                          '${(_zoom * 100).round()}%',
                          width: 72,
                          controller: controller,
                        );
                      },
                    ),

                    _toolbarButton(
                      tooltip: 'Zoom in',
                      onPressed: () {
                        setState(() {
                          _zoom = (_zoom + 0.1).clamp(0.5, 2.0);
                        });
                      },
                      width: 28,
                      child: _toolbarLabel('+', size: 18),
                    ),

                    _toolbarDivider(context),

                    MenuAnchor(
                      style: _toolbarMenuStyle(170),
                      menuChildren: [
                        for (final font in const [
                          'Arial',
                          'Times New Roman',
                          'Georgia',
                          'Verdana',
                          'Courier New',
                          'Trebuchet MS',
                          'Helvetica',
                          'Tahoma',
                          'Garamond',
                          'Palatino',
                        ])
                          MenuItemButton(
                            onPressed: () => _applyFont(font),
                            child: Text(
                              font,
                              style: TextStyle(fontFamily: font),
                            ),
                          ),
                      ],
                      builder: (context, controller, child) {
                        return _menuTrigger(
                          _displayFont,
                          width: 145,
                          controller: controller,
                        );
                      },
                    ),

                    _toolbarDivider(context),

                    _toolbarButton(
                      tooltip: 'Bold',
                      active: _formatActive(Attribute.bold.key),
                      onPressed: () => _toggleInlineFormat(Attribute.bold),
                      child: _toolbarLabel('B', weight: FontWeight.w700),
                    ),
                    _toolbarButton(
                      tooltip: 'Italic',
                      active: _formatActive(Attribute.italic.key),
                      onPressed: () => _toggleInlineFormat(Attribute.italic),
                      child: _toolbarLabel('I', style: FontStyle.italic),
                    ),
                    _toolbarButton(
                      tooltip: 'Underline',
                      active: _formatActive(Attribute.underline.key),
                      onPressed: () => _toggleInlineFormat(Attribute.underline),
                      child: _toolbarLabel(
                        'U',
                        decoration: TextDecoration.underline,
                      ),
                    ),

                    _toolbarDivider(context),

                    _toolbarButton(
                      tooltip: 'Align left',
                      active: style[Attribute.align.key]?.value == 'left',
                      onPressed: () => _applyFormat(Attribute.leftAlignment),
                      child: _toolbarLabel('≡', size: 18),
                    ),
                    _toolbarButton(
                      tooltip: 'Align center',
                      active: style[Attribute.align.key]?.value == 'center',
                      onPressed: () => _applyFormat(Attribute.centerAlignment),
                      child: _toolbarLabel('≣', size: 18),
                    ),
                    _toolbarButton(
                      tooltip: 'Align right',
                      active: style[Attribute.align.key]?.value == 'right',
                      onPressed: () => _applyFormat(Attribute.rightAlignment),
                      child: _toolbarLabel('≡', size: 18),
                    ),
                    _toolbarButton(
                      tooltip: 'Justify',
                      active: style[Attribute.align.key]?.value == 'justify',
                      onPressed: () => _applyFormat(Attribute.justifyAlignment),
                      child: _toolbarLabel('☰', size: 16),
                    ),

                    _toolbarDivider(context),

                    _toolbarButton(
                      tooltip: 'Numbered list',
                      active: style[Attribute.list.key]?.value == 'ordered',
                      onPressed: () => _applyFormat(Attribute.ol),
                      width: 38,
                      child: _toolbarLabel('1. ≡', size: 12),
                    ),
                    _toolbarButton(
                      tooltip: 'Bulleted list',
                      active: style[Attribute.list.key]?.value == 'bullet',
                      onPressed: () => _applyFormat(Attribute.ul),
                      width: 38,
                      child: _toolbarLabel('• ≡', size: 13),
                    ),

                    _toolbarDivider(context),

                    _toolbarButton(
                      tooltip: 'Decrease indent',
                      onPressed: () => _indentSelection(false),
                      width: 38,
                      child: _toolbarLabel('← ≡', size: 12),
                    ),
                    _toolbarButton(
                      tooltip: 'Increase indent',
                      onPressed: () => _indentSelection(true),
                      width: 38,
                      child: _toolbarLabel('≡ →', size: 12),
                    ),

                    _toolbarDivider(context),

                    MenuAnchor(
                      controller: _citationMenuController,
                      style: _toolbarMenuStyle(150),
                      menuChildren: [
                        for (final citation in CitationStyle.values)
                          MenuItemButton(
                            onPressed: () {
                              _citationMenuController.close();
                              _changeCitationStyle(citation);
                            },
                            child: Text(
                              citation.label,
                              style: TextStyle(
                                fontWeight: citation == _citationStyle
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                      builder: (context, controller, child) {
                        return _menuTrigger(
                          'Citation: ${_citationStyle.label}',
                          width: 130,
                          controller: controller,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentBar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF161A20),
      child: Row(
        children: [
          _toolbarButton(
            tooltip: _sidebarOpen ? 'Hide pages' : 'Show pages',
            onPressed: () {
              setState(() {
                _sidebarOpen = !_sidebarOpen;
              });
            },
            child: _toolbarLabel(_sidebarOpen ? '‹' : '›', size: 20),
          ),
          const SizedBox(width: 6),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFEA4335),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: const Text(
              '≡',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _titleController,
              style: const TextStyle(color: Color(0xFFF3F4F6), fontSize: 18),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export follows the editor step.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
              minimumSize: const Size(92, 36),
              shape: const StadiumBorder(),
            ),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  List<String> get _outlineItems {
    return _controller.document
        .toPlainText()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6)
        .toList();
  }

  void _jumpToOutline(String text) {
    final document = _controller.document.toPlainText();
    final index = document.indexOf(text);

    if (index < 0) return;

    _focusNode.requestFocus();

    _controller.updateSelection(
      TextSelection.collapsed(offset: index),
      ChangeSource.local,
    );
  }

  Widget _buildPagesSidebar(BuildContext context) {
    if (!_sidebarOpen) {
      return Container(
        width: 42,
        decoration: const BoxDecoration(
          color: Color(0xFF1B2028),
          border: Border(right: BorderSide(color: Color(0xFF2F353F))),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _toolbarButton(
              tooltip: 'Show pages',
              onPressed: () {
                setState(() {
                  _sidebarOpen = true;
                });
              },
              child: _toolbarLabel('›', size: 20),
            ),
          ),
        ),
      );
    }

    final items = _outlineItems;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF1B2028),
        border: Border(right: BorderSide(color: Color(0xFF2F353F))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pages',
                    style: TextStyle(
                      color: Color(0xFFF3F4F6),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _toolbarButton(
                  tooltip: 'Hide pages',
                  onPressed: () {
                    setState(() {
                      _sidebarOpen = false;
                    });
                  },
                  child: _toolbarLabel('‹', size: 20),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x29EA4335),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Text(
                  '▣',
                  style: TextStyle(color: Color(0xFFF87171), fontSize: 16),
                ),
                SizedBox(width: 10),
                Text(
                  'Page 1',
                  style: TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Outline',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 3),
              itemBuilder: (context, index) {
                final item = items[index];

                return InkWell(
                  onTap: () => _jumpToOutline(item),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: 5,
                            height: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF8EA0BB),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            item,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFA9B4C7),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuler(BuildContext context) {
    return Container(
      height: 34,
      color: const Color(0xFF11151B),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pageWidth = 816 * _zoom;
          final rulerArea = constraints.maxWidth > pageWidth + 48
              ? constraints.maxWidth
              : pageWidth + 48;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: rulerArea,
              child: Center(
                child: SizedBox(
                  width: pageWidth,
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 17; i++)
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Container(
                                  height: i.isEven ? 12 : 7,
                                  width: 1,
                                  color: const Color(0xFF4B5563),
                                  child: i.isEven
                                      ? Transform.translate(
                                          offset: const Offset(-2, -11),
                                          child: Text(
                                            '${i ~/ 2}',
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 8,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Positioned(
                        left: 72 * _zoom,
                        bottom: 0,
                        child: const Text(
                          '▲',
                          style: TextStyle(
                            color: Color(0xFFEA4335),
                            fontSize: 10,
                            height: 0.8,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 72 * _zoom,
                        bottom: 0,
                        child: const Text(
                          '▲',
                          style: TextStyle(
                            color: Color(0xFFEA4335),
                            fontSize: 10,
                            height: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCanvas(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = 816 * _zoom;
        final pageHeight = 1056 * _zoom;
        final minimumCanvasWidth = pageWidth + 48;
        final canvasWidth = constraints.maxWidth > minimumCanvasWidth
            ? constraints.maxWidth
            : minimumCanvasWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: canvasWidth,
            height: constraints.maxHeight,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Center(
                child: SizedBox(
                  width: pageWidth,
                  height: pageHeight,
                  child: Transform.scale(
                    scale: _zoom,
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: 816,
                      height: 1056,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 3,
                            offset: Offset(0, 1),
                            color: Color(0x33000000),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(72, 32, 72, 0),
                            child: Row(
                              children: [
                                Spacer(),
                                Text(
                                  '1',
                                  style: TextStyle(
                                    color: Color(0xFF374151),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                72,
                                38,
                                72,
                                72,
                              ),
                              child: Theme(
                                data: ThemeData.light().copyWith(
                                  textSelectionTheme:
                                      const TextSelectionThemeData(
                                        cursorColor: Color(0xFFEA4335),
                                        selectionColor: Color(0x55EA4335),
                                        selectionHandleColor: Color(0xFFEA4335),
                                      ),
                                ),
                                child: QuillEditor.basic(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  scrollController: _scrollController,
                                  config: const QuillEditorConfig(
                                    scrollable: true,
                                    expands: true,
                                    autoFocus: false,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    placeholder: 'Start writing...',
                                    textSelectionThemeData:
                                        TextSelectionThemeData(
                                          cursorColor: Color(0xFFEA4335),
                                          selectionColor: Color(0x55EA4335),
                                          selectionHandleColor: Color(
                                            0xFFEA4335,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161A20),
        border: Border(top: BorderSide(color: Color(0xFF2F353F))),
      ),
      child: Row(
        children: [
          Text(
            '$_wordCount words',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
          const SizedBox(width: 18),
          Text(
            '$_characterCount characters',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
          const SizedBox(width: 18),
          const Text(
            '|',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(width: 18),
          const Text(
            'Editing',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
          const Spacer(),
          Text(
            'Zoom: ${(_zoom * 100).round()}%',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Column(
      children: [
        _buildDocumentBar(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              return Container(
                color: const Color(0xFF11151B),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) _buildPagesSidebar(context),
                    Expanded(
                      child: Column(
                        children: [
                          _buildFormattingToolbar(context),
                          _buildRuler(context),
                          Expanded(child: _buildDocumentCanvas(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildStatusBar(context),
      ],
    );
  }
}
