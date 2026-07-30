//
//  EmulatorControlsOverlay.swift
//  romm
//
//  Created by Ilyas Hallak on 11.12.25.
//

import SwiftUI

struct EmulatorControlsOverlay: View {
    @ObservedObject var viewModel: EmulatorViewModel
    let onExit: () -> Void

    var body: some View {
        VStack {
            // Top Bar - Exit Button
            HStack {
                Spacer()

                // Exit Button
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
                .padding()
            }

            Spacer()

            // Bottom Controls
            HStack(spacing: 30) {
                // Settings (future: adjust display, audio, etc.)
                Button(action: {
                    // Show settings sheet (future implementation)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 30))
                        Text("Settings")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
                .disabled(true) // Disabled for now
                .opacity(0.5)

                // Screenshot (future feature)
                Button(action: {
                    // Take screenshot (future implementation)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                        Text("Screenshot")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
                .disabled(true) // Disabled for now
                .opacity(0.5)
            }
            .padding(.bottom, 40)
            .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.4), .clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
