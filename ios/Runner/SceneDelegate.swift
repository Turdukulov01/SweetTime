import Flutter
import GoogleSignIn
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // На новой UIScene-архитектуре Flutter входящие URL приходят сюда, а не в
  // AppDelegate. Без проброса google_sign_in не получает OAuth-callback и вход
  // «зависает» после «Продолжить». Официальная интеграция GoogleSignIn для сцен.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      if GIDSignIn.sharedInstance.handle(context.url) {
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
