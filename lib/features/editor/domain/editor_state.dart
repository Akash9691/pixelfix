import 'dart:ui' as ui;

enum EditorTool { erase, select, expand, background, upscale, styles, combos }

/// A finished-but-not-yet-applied AI result (select → preview → apply / cancel).
class Pending {
  Pending(this.image, this.kind);
  final ui.Image image;

  /// erase | expand | background | upscale | style | combo
  final String kind;
}

class Toast {
  Toast(this.id, this.text, {this.error = false});
  final int id;
  final String text;
  final bool error;
}

class BusyInfo {
  const BusyInfo(this.label, {this.progress, this.cancellable = true});
  final String label;

  /// 0..1, or null when indeterminate.
  final double? progress;
  final bool cancellable;
}

class EditorState {
  const EditorState({
    this.image,
    this.original,
    this.pending,
    this.tool = EditorTool.erase,
    this.busy,
    this.canUndo = false,
    this.canRedo = false,
    this.comparing = false,
    this.brushDp = 28,
    this.eraserMode = false,
    this.toast,
    this.hint,
    this.preparing = false,
  });

  final ui.Image? image;
  final ui.Image? original;
  final Pending? pending;
  final EditorTool tool;
  final BusyInfo? busy;
  final bool canUndo, canRedo, comparing;

  /// Brush size in screen dp (converted to image pixels while painting).
  final double brushDp;
  final bool eraserMode;

  final Toast? toast;
  final String? hint;

  /// First use of a model: "Preparing AI…".
  final bool preparing;

  ui.Image? get shown => comparing ? original : (pending?.image ?? image);
  bool get hasImage => image != null;

  EditorState copyWith({
    ui.Image? image,
    ui.Image? original,
    Pending? Function()? pending,
    EditorTool? tool,
    BusyInfo? Function()? busy,
    bool? canUndo,
    bool? canRedo,
    bool? comparing,
    double? brushDp,
    bool? eraserMode,
    Toast? toast,
    String? Function()? hint,
    bool? preparing,
  }) =>
      EditorState(
        image: image ?? this.image,
        original: original ?? this.original,
        pending: pending != null ? pending() : this.pending,
        tool: tool ?? this.tool,
        busy: busy != null ? busy() : this.busy,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
        comparing: comparing ?? this.comparing,
        brushDp: brushDp ?? this.brushDp,
        eraserMode: eraserMode ?? this.eraserMode,
        toast: toast ?? this.toast,
        hint: hint != null ? hint() : this.hint,
        preparing: preparing ?? this.preparing,
      );
}
