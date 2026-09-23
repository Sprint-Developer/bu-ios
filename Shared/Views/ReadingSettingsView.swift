import SwiftUI

struct ReadingSettingsView: View {
    @ObservedObject var settings: ReadingSettings

    private let sampleAr = "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا"
    private let sampleEn = "So truly where there is hardship there is also ease."
    private let sampleUr = "پس یقیناً مشکل کے ساتھ آسانی ہے۔"

    var body: some View {
        Form {
            Section("Reading language") {
                Picker("Show", selection: $settings.readingLanguage) {
                    ForEach(AppReadingLanguage.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                Text("Like IslamOne: pick Arabic+English, Arabic+Urdu, or all three. You can still fine-tune toggles below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Translations") {
                Picker("English", selection: $settings.englishTranslationID) {
                    ForEach(QuranAPI.englishChoices) { c in
                        Text(c.label).tag(c.id)
                    }
                }
                Picker("Urdu", selection: $settings.urduTranslationID) {
                    ForEach(QuranAPI.urduChoices) { c in
                        Text(c.label).tag(c.id)
                    }
                }
                Text("Changing a translation refreshes new ayahs with clean text (footnotes stripped). Re-open a surah to reload.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("When sharing") {
                Toggle("Include Arabic", isOn: $settings.shareArabic)
                Toggle("Include English", isOn: $settings.shareEnglish)
                Toggle("Include Urdu", isOn: $settings.shareUrdu)
                Text("Reference is always included. Pick one, two, or all languages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Layout") {
                Picker("English alignment", selection: $settings.textAlign) {
                    ForEach(TextAlignMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                Text("Arabic and Urdu stay right-aligned (RTL).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Language labels", isOn: $settings.showLangLabels)
            }

            Section("Show / hide") {
                Toggle("Arabic", isOn: $settings.showArabic)
                Toggle("English", isOn: $settings.showEnglish)
                Toggle("Urdu", isOn: $settings.showUrdu)
            }

            Section("Arabic") {
                Picker("Font", selection: $settings.arabicFont) {
                    ForEach(ScriptFont.arabicChoices) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                Text("Indo-Pak / Nastaliq fonts use Indo-Pak script. Uthmani Hafs, Amiri, Noto Naskh use Uthmani text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $settings.arabicSize, in: 16...42, step: 1)
                Text("\(Int(settings.arabicSize)) pt").font(.caption).foregroundStyle(.secondary)
                Slider(value: $settings.arabicLineSpacing, in: 0...10, step: 1) {
                    Text("Line height")
                }
                Text("Line height \(Int(settings.arabicLineSpacing))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ColorPicker("Color", selection: $settings.arabicColor, supportsOpacity: false)
            }

            Section("English") {
                Picker("Font", selection: $settings.englishFont) {
                    ForEach(ScriptFont.englishChoices) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                Slider(value: $settings.englishSize, in: 12...28, step: 1)
                ColorPicker("Color", selection: $settings.englishColor, supportsOpacity: false)
            }

            Section("Urdu") {
                Picker("Font", selection: $settings.urduFont) {
                    ForEach(ScriptFont.urduChoices) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                Slider(value: $settings.urduSize, in: 12...32, step: 1)
                Text("\(Int(settings.urduSize)) pt").font(.caption).foregroundStyle(.secondary)
                Slider(value: $settings.urduLineSpacing, in: 0...14, step: 1) {
                    Text("Line height")
                }
                Text("Line height \(Int(settings.urduLineSpacing))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ColorPicker("Color", selection: $settings.urduColor, supportsOpacity: false)
            }

            Section("Preview") {
                TripleText(arabic: sampleAr, english: sampleEn, urdu: sampleUr)
                    .padding(.vertical, 4)
            }

            Section {
                Button("Reset to defaults", role: .destructive) {
                    settings.reset()
                }
            }
        }
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
    }
}
