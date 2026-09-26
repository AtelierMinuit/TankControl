import SwiftUI

public struct InkSaverCenterView: View {
    @ObservedObject var printer: PrinterManager
    @StateObject private var inkSaverService = InkSaverService()
    @State private var sliderPos: CGFloat = 0.5

    @State private var showSuccessBanner: Bool = false
    @State private var bannerMessage: String = ""

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("InkSaver Center")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Ajusta el ahorro de tinta para impresiones diarias.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if inkSaverService.isCupsSynced {
                        Label("Sincronizado", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // MARK: - Banner
                if showSuccessBanner {
                    HStack {
                        Label(bannerMessage, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                        Button(action: { showSuccessBanner = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
                }

                // MARK: - Main Control Section
                VStack(spacing: 20) {
                    // Visual Preview
                    VisualComparatorView(sliderPosition: $sliderPos, savingsPercent: inkSaverService.savingsPercent)
                        .frame(height: 140)
                    
                    // Slider
                    VStack(spacing: 8) {
                        HStack {
                            Text("Porcentaje de Ahorro")
                                .font(.headline)
                            Spacer()
                            Text("\(inkSaverService.savingsPercent)%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color.accentColor)
                                .monospacedDigit()
                        }
                        
                        Slider(
                            value: Binding<Double>(
                                get: { Double(inkSaverService.savingsPercent) },
                                set: { inkSaverService.savingsPercent = Int($0) }
                            ),
                            in: 0...75,
                            step: 5
                        )
                        
                        HStack {
                            Text("Normal").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("Ahorro Máximo").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Apply Button
                    HStack {
                        Spacer()
                        Button(action: applyCupsDefault) {
                            if inkSaverService.isApplying {
                                ProgressView().controlSize(.small)
                            }
                            Text("Establecer como Predeterminado")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(inkSaverService.isApplying)
                    }
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                
                Spacer(minLength: 40)
            }
            .padding(24)
        }
    }

    private func applyCupsDefault() {
        inkSaverService.applyCupsSetting { result in
            switch result {
            case .success:
                self.bannerMessage = "Ajuste aplicado a la cola de impresión."
                withAnimation { self.showSuccessBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation { self.showSuccessBanner = false }
                }
            case .failure(let error):
                self.bannerMessage = "Error: \(error.localizedDescription)"
                withAnimation { self.showSuccessBanner = true }
            }
        }
    }
}

public struct VisualComparatorView: View {
    @Binding var sliderPosition: CGFloat
    let savingsPercent: Int

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let dividerX = width * sliderPosition

            ZStack(alignment: .leading) {
                // LADO IZQUIERDO: Eco
                sampleDocument(isEco: true)

                // LADO DERECHO: Original
                sampleDocument(isEco: false)
                    .mask(
                        HStack(spacing: 0) {
                            Spacer(minLength: dividerX)
                            Rectangle().frame(width: max(0, width - dividerX))
                        }
                    )

                // Divisor
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
                    .offset(x: dividerX)

                // Tirador
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(radius: 3)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 10, weight: .bold)).foregroundColor(.accentColor))
                    .offset(x: dividerX - 12, y: geo.size.height / 2 - 12)
                    .gesture(
                        DragGesture().onChanged { value in
                            sliderPosition = max(0.05, min(0.95, value.location.x / width))
                        }
                    )
            }
        }
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func sampleDocument(isEco: Bool) -> some View {
        let alpha = isEco ? max(0.2, 1.0 - (Double(savingsPercent) / 100.0)) : 1.0
        
        return ZStack {
            Color.white
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sample Report").font(.system(size: 18, weight: .bold)).foregroundColor(.black)
                    Spacer()
                    Image(systemName: "chart.pie.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.blue.opacity(alpha))
                }
                
                Text("This text is protected by EdgePreserve™ and remains sharp 100% black regardless of the eco setting selected.")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .lineSpacing(2)
                
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.cyan.opacity(alpha)).frame(height: 40)
                    RoundedRectangle(cornerRadius: 4).fill(Color.purple.opacity(alpha)).frame(height: 40)
                    RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(alpha)).frame(height: 40)
                }
                
                Text(isEco ? "CON INKSAVER (\(savingsPercent)%)" : "ORIGINAL (100%)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
        }
    }
}
