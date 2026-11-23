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
            // From IMG_7623.jpg (1500x844)
            return (0.2587, 0.1682, 0.4813, 0.5687)
        } else {
            // From IMG_7621.jpg (1500x3251)
            return (0.0400, 0.0692, 0.9180, 0.3301)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // Prefer full-bleed fit for landscape so the whole skin is visible
            let scale: CGFloat = isLandscape
                ? min(size.width / 1500, size.height / 844)
                : min(size.width / 1500, size.height / 3251)
            let skinW = (isLandscape ? 1500 : 1500) * scale
            let skinH = (isLandscape ? 844 : 3251) * scale
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
        RoundedRectangle(cornerRadius: isLandscape ? 36 : 48, style: .continuous)
            .fill(Color(white: 0.96))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    @ViewBuilder
    private func controls(origin: CGPoint, skinW: CGFloat, skinH: CGFloat) -> some View {
        if isLandscape {
            // Landscape layout matching IMG_7623
            // Left side: D-pad above left stick
            dpad
                .position(x: origin.x + skinW * 0.16, y: origin.y + skinH * 0.42)
            stickView(offset: controller.leftStick)
                .position(x: origin.x + skinW * 0.16, y: origin.y + skinH * 0.72)

            // Right side: face buttons above right stick
            faceButtons
                .position(x: origin.x + skinW * 0.84, y: origin.y + skinH * 0.42)
            stickView(offset: controller.rightStick)
                .position(x: origin.x + skinW * 0.84, y: origin.y + skinH * 0.72)

            // Top shoulders
            HStack(spacing: skinW * 0.04) {
                shoulder("L", pressed: controller.lPressed)
                shoulder("ZL", pressed: controller.zlPressed)
            }
            .position(x: origin.x + skinW * 0.16, y: origin.y + skinH * 0.12)

            HStack(spacing: skinW * 0.04) {
                shoulder("ZR", pressed: controller.zrPressed)
                shoulder("R", pressed: controller.rPressed)
            }
            .position(x: origin.x + skinW * 0.84, y: origin.y + skinH * 0.12)

            // Bottom center system buttons
            HStack(spacing: skinW * 0.06) {
                smallButton("-")
                smallButton("⚙") // gear
                smallButton("+")
            }
            .position(x: origin.x + skinW * 0.50, y: origin.y + skinH * 0.88)
        } else {
            // Portrait layout matching IMG_7621 (screen on top)
            // Shoulders under screen
            HStack(spacing: skinW * 0.12) {
                HStack(spacing: 8) {
                    shoulder("L", pressed: controller.lPressed)
                    shoulder("ZL", pressed: controller.zlPressed)
                }
                HStack(spacing: 8) {
                    shoulder("ZR", pressed: controller.zrPressed)
                    shoulder("R", pressed: controller.rPressed)
                }
            }
            .position(x: origin.x + skinW * 0.50, y: origin.y + skinH * 0.42)

            // D-pad left, face right
            dpad
                .position(x: origin.x + skinW * 0.28, y: origin.y + skinH * 0.55)
            faceButtons
                .position(x: origin.x + skinW * 0.72, y: origin.y + skinH * 0.55)

            // Sticks lower
            stickView(offset: controller.leftStick)
                .position(x: origin.x + skinW * 0.28, y: origin.y + skinH * 0.78)
            stickView(offset: controller.rightStick)
                .position(x: origin.x + skinW * 0.72, y: origin.y + skinH * 0.78)

            // Bottom system
            HStack(spacing: skinW * 0.08) {
                smallButton("-")
                smallButton("⚙")
                smallButton("+")
            }
            .position(x: origin.x + skinW * 0.50, y: origin.y + skinH * 0.92)
        }
    }

    private var dpad: some View {
        ZStack {
            // Cross shape approximation
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: 28, height: 70)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: 70, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            // Direction indicators
            Text("|").font(.system(size: 10)).offset(y: -22)
            Text("|").font(.system(size: 10)).offset(y: 22)
            Text("-").font(.system(size: 12)).offset(x: -22)
            Text("-").font(.system(size: 12)).offset(x: 22)
        }
        .frame(width: 70, height: 70)
    }

    private var faceButtons: some View {
        ZStack {
            skinButton("X", pressed: controller.xPressed).offset(x: 0, y: -26)
            skinButton("Y", pressed: controller.yPressed).offset(x: -26, y: 0)
            skinButton("A", pressed: controller.aPressed).offset(x: 26, y: 0)
            skinButton("b", pressed: controller.bPressed).offset(x: 0, y: 26)
        }
    }

    private func stickView(offset: CGPoint) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color.gray.opacity(0.35), lineWidth: 3)
                .background(Circle().fill(Color.white))
                .frame(width: 64, height: 64)
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .frame(width: 32, height: 32)
                .offset(x: offset.x * 14, y: -offset.y * 14)
                .animation(.easeOut(duration: 0.08), value: offset)
        }
    }

    private func skinButton(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.gray.opacity(0.8))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.gray.opacity(0.35), lineWidth: 1))
            )
            .scaleEffect(pressed ? 0.86 : 1.0)
            .offset(y: pressed ? 2.5 : 0)
            .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private func shoulder(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.gray.opacity(0.75))
            .frame(width: 42, height: 22)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            )
            .scaleEffect(pressed ? 0.90 : 1.0)
            .offset(y: pressed ? 1.5 : 0)
            .animation(.easeOut(duration: 0.07), value: pressed)
    }

    private func smallButton(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            )
    }
}
