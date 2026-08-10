//
//  SettingsView.swift
//  watch-zone Watch App
//
//  Created by Darren DeLitizia on 8/9/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lowerLimit") private var lowerLimit = 105
    @AppStorage("upperLimit") private var upperLimit = 140

    var body: some View {
        List {
            Section() {
                ZoneStepperRow(title: "Lower", value: $lowerLimit, range: 40...upperLimit, step: 1)
                ZoneStepperRow(title: "Upper", value: $upperLimit, range: lowerLimit...220, step: 1)
            }
        }
        .navigationTitle("BPM")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct ZoneStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.body)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 40)

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .disabled(value >= range.upperBound)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
