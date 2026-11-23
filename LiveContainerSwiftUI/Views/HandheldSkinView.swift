import SwiftUI

/// Custom white handheld console skin overlay matching the provided images.
/// Landscape (IMG_7623 style): full display with screen centered.
/// Portrait (IMG_7621 style): screen near top.
/// Driven by LiveBoardControllerInput for visual press / stick movement.
struct HandheldSkinView: View {
    @ObservedObject var controller: LiveBoardControllerInput
    var isLandscape: Bool = true
    var skinImage: UIImage? = nil

    // Measured from the uploaded images
    private var screenRel: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        if isLandscape {
            // IMG_7623 original: 1792x1008, game window at (463,169) size 863x574.
            return (463.0/1792.0, 169.0/1008.0, 863.0/1792.0, 574.0/1008.0)
        } else {
            // IMG_7621 original: 923x2000, game window at (37,138) size 847x661.
            return (37.0/923.0, 138.0/2000.0, 847.0/923.0, 661.0/2000.0)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let baseW: CGFloat = isLandscape ? 1792 : 923
            let baseH: CGFloat = isLandscape ? 1008 : 2000
            let scale = min(size.width / baseW, size.height / baseH)
            let skinW = baseW * scale
            let skinH = baseH * scale
            let origin = CGPoint(
                x: (size.width - skinW) / 2,
                y: (size.height - skinH) / 2
            )

            ZStack {
                // Base skin
                Group {
                    if let img = skinImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        skinBase
                    }
                }
                .frame(width: skinW, height: skinH)
                .position(x: origin.x + skinW/2, y: origin.y + skinH/2)

                // Game screen area (black)
                let sr = screenRel
                let sx = origin.x + sr.x * skinW
                let sy = origin.y + sr.y * skinH
                let sw = sr.w * skinW
                let sh = sr.h * skinH
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .frame(width: sw, height: sh)
                    .position(x: sx + sw/2, y: sy + sh/2)

                // Controls overlaid (positions tuned to the photos)
                controls(origin: origin, skinW: skinW, skinH: skinH)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }

    private var skinBase: some View {
        RoundedRectangle(cornerRadius: isLandscape ? 40 : 52, style: .continuous)
            .fill(Color(white: 0.97))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }

    @ViewBuilder
    private func controls(origin: CGPoint, skinW: CGFloat, skinH: CGFloat) -> some View {
        if isLandscape {
            // Landscape layout matching IMG_7623
            dpad
                .position(x: origin.x + skinW * 0.155, y: origin.y + skinH * 0.40)
            stickView(offset: controller.leftStick)
                .position(x: origin.x + skinW * 0.155, y: origin.y + skinH * 0.73)

            faceButtons
                .position(x: origin.x + skinW * 0.845, y: origin.y + skinH * 0.40)
            stickView(offset: controller.rightStick)
                .position(x: origin.x + skinW * 0.845, y: origin.y + skinH * 0.73)

            HStack(spacing: skinW * 0.035) {
                shoulder("L", pressed: controller.lPressed)
                shoulder("ZL", pressed: controller.zlPressed)
            }
            .position(x: origin.x + skinW * 0.155, y: origin.y + skinH * 0.105)

            HStack(spacing: skinW * 0.035) {
                shoulder("ZR", pressed: controller.zrPressed)
                shoulder("R", pressed: controller.rPressed)
            }
            .position(x: origin.x + skinW * 0.845, y: origin.y + skinH * 0.105)

            HStack(spacing: skinW * 0.055) {
                smallButton("-")
                smallButton("⚙")
                smallButton("+")
            }
            .position(x: origin.x + skinW * 0.50, y: origin.y + skinH * 0.895)
        } else {
            // Portrait layout matching IMG_7621 (screen on top)
            HStack(spacing: skinW * 0.10) {
                HStack(spacing: 6) {
                    shoulder("L", pressed: controller.lPressed)
                    shoulder("ZL", pressed: controller.zlPressed)
                }
                HStack(spacing: 6) {
                    shoulder("ZR", pressed: controller.zrPressed)
                    shoulder("R", pressed: controller.rPressed)
                }
            }
            .position(x: origin.x + skinW * 0.50, y: origin.y + skinH * 0.415)

            dpad
                .position(x: origin.x + skinW * 0.27, y: origin.y + skinH * 0.54)
            faceButtons
                .position(x: origin.x + skinW * 0.73, y: origin.y + skinH * 0.54)

            stickView(offset: controller.leftStick)
                .position(x: origin.x + skinW * 0.27, y: origin.y + skinH * 0.78)
            stickView(offset: controller.rightStick)
                .position(x: origin.x + skinW * 0.73, y: origin.y + skinH * 0.78)

            HStack(spacing: skinW * 0.07) {
                smallButton("-")
                smallButton("⚙")
                smallButton("+")
            }
            .position(x: origin.x + skinW * 0.50, y: origin.y + skinH * 0.925)
        }
    }

    private var dpad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 26, height: 68)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1.2))
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 68, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1.2))
            Text("|").font(.system(size: 9, weight: .medium)).foregroundStyle(.gray.opacity(0.6)).offset(y: -20)
            Text("|").font(.system(size: 9, weight: .medium)).foregroundStyle(.gray.opacity(0.6)).offset(y: 20)
            Text("-").font(.system(size: 11, weight: .medium)).foregroundStyle(.gray.opacity(0.6)).offset(x: -20)
            Text("-").font(.system(size: 11, weight: .medium)).foregroundStyle(.gray.opacity(0.6)).offset(x: 20)
        }
        .frame(width: 68, height: 68)
    }

    private var faceButtons: some View {
        ZStack {
            skinButton("X", pressed: controller.xPressed).offset(x: 0, y: -28)
            skinButton("Y", pressed: controller.yPressed).offset(x: -28, y: 0)
            skinButton("A", pressed: controller.aPressed).offset(x: 28, y: 0)
            skinButton("b", pressed: controller.bPressed).offset(x: 0, y: 28)
        }
    }

    private func stickView(offset: CGPoint) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2.5)
                .background(Circle().fill(Color.white))
                .frame(width: 62, height: 62)
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
                .frame(width: 30, height: 30)
                .offset(x: offset.x * 13, y: -offset.y * 13)
                .animation(.easeOut(duration: 0.08), value: offset)
        }
    }

    private func skinButton(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.gray.opacity(0.75))
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            )
            .scaleEffect(pressed ? 0.84 : 1.0)
            .offset(y: pressed ? 2.8 : 0)
            .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private func shoulder(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.gray.opacity(0.7))
            .frame(width: 40, height: 20)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(Color.gray.opacity(0.28), lineWidth: 1))
            )
            .scaleEffect(pressed ? 0.88 : 1.0)
            .offset(y: pressed ? 1.6 : 0)
            .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private func smallButton(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.gray.opacity(0.28), lineWidth: 1))
            )
    }
}
