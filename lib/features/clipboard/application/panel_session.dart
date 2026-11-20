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
