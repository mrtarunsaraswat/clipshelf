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
