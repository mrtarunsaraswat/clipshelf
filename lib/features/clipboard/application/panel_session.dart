import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clipboard_snapshot.dart';

class PanelSession {
  const PanelSession({
    this.sequence = 0,
    this.visible = true,
    this.presentation = PanelPresentation.shelf,
  });
  final int sequence;
  final bool visible;
  final PanelPresentation presentation;
}

final panelSessionProvider =
    NotifierProvider<PanelSessionController, PanelSession>(
      PanelSessionController.new,
    );

/// Latest ⌘-number quick-use request from the native panel. [sequence] makes
/// repeating the same number observable.
class QuickUseRequest {
  const QuickUseRequest(this.sequence, this.index);
  final int sequence, index;
}

final quickUseRequestProvider =
    NotifierProvider<QuickUseRequestController, QuickUseRequest?>(
      QuickUseRequestController.new,
    );

class QuickUseRequestController extends Notifier<QuickUseRequest?> {
  @override
  QuickUseRequest? build() => null;
  void request(int index) =>
      state = QuickUseRequest((state?.sequence ?? 0) + 1, index);
}

/// Route names that decide which dialogs survive hiding and reopening the panel.
const editorDialogRoute = 'editor';
const preferencesDialogRoute = 'preferences';

/// Set when Preferences sends the user to another app (System Settings for
/// Accessibility, the folder picker), so reopening returns to Preferences.
final returnToPreferencesProvider =
    NotifierProvider<ReturnToPreferencesController, bool>(
      ReturnToPreferencesController.new,
    );

class ReturnToPreferencesController extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class PanelSessionController extends Notifier<PanelSession> {
  @override
  PanelSession build() => const PanelSession();
  void closed() => state = PanelSession(
    sequence: state.sequence + 1,
    presentation: state.presentation,
    visible: false,
  );
  void opened(PanelPresentation presentation) => state = PanelSession(
    sequence: state.sequence + 1,
    presentation: presentation,
  );
}
