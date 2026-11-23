import SwiftUI

/// Custom handheld skin overlay.
/// Landscape uses full-display (aspectFit) with the exact screen offsets from the skin image.
/// Portrait uses the corresponding offsets.
struct HandheldSkinView: View {
    @ObservedObject var controller: LiveBoardControllerInput
    var isLandscape: Bool = true
    /// Optional skin image. If nil a simple placeholder is drawn so layout can be verified.
    var skinImage: UIImage? = nil

    // Exact values from the provided skin sheet
    private var imageSize: CGSize {
        isLandscape ? CGSize(width: 1792, height: 1008) : CGSize(width: 923, height: 2000)
    }
    private var screenOffset: CGPoint {
        isLandscape ? CGPoint(x: 463, y: 169) : CGPoint(x: 37, y: 138)
    }
    private var screenSize: CGSize {
        isLandscape ? CGSize(width: 863, height: 574) : CGSize(width: 847, height: 661)
    }

    var body: some View {
        GeometryReader { geo in
            let screen = geo.size
            // Scale so the entire skin is visible (full display in landscape)
            let scale = min(screen.width / imageSize.width, screen.height / imageSize.height)
            let skinW = imageSize.width * scale
            let skinH = imageSize.height * scale
            let skinOrigin = CGPoint(
                x: (screen.width - skinW) / 2,
                y: (screen.height - skinH) / 2
            )

            ZStack {
                // Skin background (full display)
                Group {
                    if let img = skinImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
                .frame(width: skinW, height: skinH)
                .position(x: skinOrigin.x + skinW/2, y: skinOrigin.y + skinH/2)

                // Game viewport placeholder (the real metal view goes here in the guest)
                let gx = skinOrigin.x + screenOffset.x * scale
                let gy = skinOrigin.y + screenOffset.y * scale
                let gw = screenSize.width * scale
                let gh = screenSize.height * scale
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                    .frame(width: gw, height: gh)
                    .position(x: gx + gw/2, y: gy + gh/2)

                // Left stick
                stickView(offset: controller.leftStick, label: "L")
                    .position(x: skinOrigin.x + skinW * 0.22, y: skinOrigin.y + skinH * 0.62)

                // Right stick
                stickView(offset: controller.rightStick, label: "R")
                    .position(x: skinOrigin.x + skinW * 0.78, y: skinOrigin.y + skinH * 0.62)

                // Face buttons
                faceButtons
                    .position(x: skinOrigin.x + skinW * 0.78, y: skinOrigin.y + skinH * 0.38)

                // Shoulders / triggers (top)
                HStack(spacing: skinW * 0.35) {
                    shoulder("L", pressed: controller.lPressed)
                    shoulder("R", pressed: controller.rPressed)
                }
                .position(x: skinOrigin.x + skinW/2, y: skinOrigin.y + skinH * 0.12)

                HStack(spacing: skinW * 0.42) {
                    shoulder("ZL", pressed: controller.zlPressed)
                    shoulder("ZR", pressed: controller.zrPressed)
                }
                .position(x: skinOrigin.x + skinW/2, y: skinOrigin.y + skinH * 0.05)
            }
            .frame(width: screen.width, height: screen.height)
        }
        .ignoresSafeArea()
    }

    private func stickView(offset: CGPoint, label: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 70, height: 70)
            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .offset(x: offset.x * 16, y: -offset.y * 16)
                .animation(.easeOut(duration: 0.08), value: offset)
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
        }
    }

    private var faceButtons: some View {
        ZStack {
            skinButton("A", pressed: controller.aPressed).offset(x: 22, y: 22)
            skinButton("B", pressed: controller.bPressed).offset(x: -22, y: 22)
            skinButton("X", pressed: controller.xPressed).offset(x: -22, y: -22)
            skinButton("Y", pressed: controller.yPressed).offset(x: 22, y: -22)
        }
    }

    private func skinButton(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .frame(width: 34, height: 34)
            .background(Circle().fill(pressed ? Color.gray.opacity(0.55) : Color.white))
            .scaleEffect(pressed ? 0.88 : 1.0)
            .offset(y: pressed ? 2 : 0)
            .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private func shoulder(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.caption.bold())
            .frame(width: 56, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(pressed ? Color.gray.opacity(0.5) : Color.white.opacity(0.85))
            )
            .scaleEffect(pressed ? 0.92 : 1.0)
            .offset(y: pressed ? 1.5 : 0)
            .animation(.easeOut(duration: 0.07), value: pressed)
    }
}
