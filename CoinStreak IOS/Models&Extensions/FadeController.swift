import SwiftUI

final class FadeHostingController<Content: View>: UIHostingController<Content> {
    override init(rootView: Content) {
        super.init(rootView: rootView)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

final class AnchorController: UIViewController {}

struct FadeFullScreenCover<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    final class Coordinator {
        weak var presented: UIViewController?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AnchorController {
        AnchorController()
    }

    func updateUIViewController(_ anchor: AnchorController, context: Context) {
        // Present if requested and we aren't already showing our own cinematic
        if isPresented, context.coordinator.presented == nil {
            let controller = FadeHostingController(rootView: content())
            controller.isModalInPresentation = true  // no swipe-to-dismiss
            context.coordinator.presented = controller
            anchor.present(controller, animated: true, completion: nil)
            return
        }

        // Dismiss only the cinematic we presented (do NOT touch other sheets)
        if !isPresented, let presented = context.coordinator.presented {
            presented.dismiss(animated: true) {
                context.coordinator.presented = nil
            }
        }
    }
}
