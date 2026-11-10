#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // MAINTENANCE : captures d'ecran autorisees le temps de la maintenance du
  // projet. Pour retablir la protection, de-commenter l'appel ci-dessous et
  // recompiler.
  // ExclureDeLaCapture();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

// La fenetre refuse d'etre capturee.
//
// L'application affiche des dossiers d'eleves, des consultations medicales
// et des inventaires d'armement : une capture d'ecran sort ces donnees sans
// laisser de trace au journal d'audit, et circule ensuite sans controle.
//
// WDA_MONITOR laisse la fenetre visible sur le moniteur et la remplace par
// du noir dans tout ce que Windows capture : Impr. ecran, Outil Capture
// d'ecran, Xbox Game Bar, partage de bureau.
//
// WDA_EXCLUDEFROMCAPTURE, plus recent et plus elegant -- il retire la fenetre
// de la capture au lieu de la noircir --, est INUTILISABLE ICI : il fait
// echouer la presentation du swapchain de Flutter, et l'application se ferme
// d'elle-meme dans la seconde. Rien ne le signale : elle compile, demarre,
// et sort avec le code 0. Ne pas le remettre sans avoir relance l'executable
// et compte jusqu'a dix.
//
// CE QU'IL NE FAIT PAS : empecher qu'on photographie l'ecran avec un autre
// appareil. Aucun reglage logiciel ne le peut.
//
// Pour une version de diagnostic -- pour envoyer une capture decrivant une
// anomalie --, commenter l'appel dans OnCreate et recompiler.
void FlutterWindow::ExclureDeLaCapture() {
  HWND fenetre = GetHandle();
  if (fenetre == nullptr) {
    return;
  }
  SetWindowDisplayAffinity(fenetre, WDA_MONITOR);
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
