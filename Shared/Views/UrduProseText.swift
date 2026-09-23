import SwiftUI
import UIKit

// MARK: - Shaped Arabic / Urdu (UIKit Core Text)

/// Renders long Urdu/Arabic with UIKit Core Text (joining + RTL).
/// SwiftUI `Text` + Nastaliq isolates glyphs on long tafsir; short Sahaba blurbs are fine.
struct ShapedArabicText: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 20
    var lineSpacing: CGFloat = 4
    /// PostScript name from Reading settings (e.g. NotoNastaliqUrdu-Regular). nil → system.
    var postScriptName: String? = nil
    var textColor: UIColor = .label
    var baseWritingDirection: NSWritingDirection = .rightToLeft
    var forceRTL: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let tv = Self.makeSelectableTextView()
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let font = Self.uiFont(named: postScriptName, size: fontSize)
        let para = NSMutableParagraphStyle()
        para.alignment = forceRTL ? .right : .natural
        para.baseWritingDirection = baseWritingDirection
        para.lineSpacing = lineSpacing

        if forceRTL {
            tv.semanticContentAttribute = .forceRightToLeft
            tv.textAlignment = .right
        } else {
            tv.semanticContentAttribute = .unspecified
            tv.textAlignment = .natural
        }
        tv.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: para
            ]
        )
        tv.textColor = textColor
        context.coordinator.lastText = text
        context.coordinator.fontSize = fontSize
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w: CGFloat
        if let pw = proposal.width, pw > 32 {
            w = pw
        } else {
            w = UIScreen.main.bounds.width - 72
        }
        uiView.textContainer.size = CGSize(width: w, height: .greatestFiniteMagnitude)
        let fitting = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: w, height: max(ceil(fitting.height), fontSize * 1.5))
    }

    static func makeSelectableTextView() -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.isUserInteractionEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = true
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return tv
    }

    static func uiFont(named postScriptName: String?, size: CGFloat) -> UIFont {
        if let name = postScriptName, let custom = UIFont(name: name, size: size) {
            return custom
        }
        return .systemFont(ofSize: size)
    }

    final class Coordinator {
        var lastText = ""
        var fontSize: CGFloat = 20
    }
}

/// Full-width shaped Urdu block for tafsir / long prose (Nastaliq via Reading settings).
struct ShapedUrduBlock: View {
    let text: String
    var fontSize: CGFloat = 20
    var lineSpacing: CGFloat = 4
    var postScriptName: String? = nil
    var textColor: UIColor = .label

    var body: some View {
        ShapedArabicText(
            text: text,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            postScriptName: postScriptName,
            textColor: textColor
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - Mixed English + inline Arabic (selectable)

/// English prose where Arabic/Urdu runs use a proper Arabic font (fixes broken inline words).
struct MixedScriptProseText: UIViewRepresentable {
    let text: String
    var englishSize: CGFloat = 17
    var arabicSize: CGFloat = 18
    var arabicPostScriptName: String? = nil
    var englishColor: UIColor = .secondaryLabel
    var arabicColor: UIColor = .label
    var lineSpacing: CGFloat = 6

    func makeUIView(context: Context) -> UITextView {
        ShapedArabicText.makeSelectableTextView()
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        tv.semanticContentAttribute = .unspecified
        tv.textAlignment = .natural
        tv.attributedText = Self.makeAttributed(
            text: text,
            englishSize: englishSize,
            arabicSize: arabicSize,
            arabicPostScriptName: arabicPostScriptName,
            englishColor: englishColor,
            arabicColor: arabicColor,
            lineSpacing: lineSpacing
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w: CGFloat
        if let pw = proposal.width, pw > 32 {
            w = pw
        } else {
            w = UIScreen.main.bounds.width - 72
        }
        uiView.textContainer.size = CGSize(width: w, height: .greatestFiniteMagnitude)
        let fitting = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: w, height: max(ceil(fitting.height), englishSize * 1.5))
    }

    static func makeAttributed(
        text: String,
        englishSize: CGFloat,
        arabicSize: CGFloat,
        arabicPostScriptName: String?,
        englishColor: UIColor,
        arabicColor: UIColor,
        lineSpacing: CGFloat
    ) -> NSAttributedString {
        let enFont = UIFont.systemFont(ofSize: englishSize)
        let arFont = ShapedArabicText.uiFont(named: arabicPostScriptName, size: arabicSize)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        para.alignment = .natural
        para.baseWritingDirection = .leftToRight

        let out = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: enFont,
                .foregroundColor: englishColor,
                .paragraphStyle: para
            ]
        )

        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        // Arabic / Urdu script blocks (including diacritics & presentation forms)
        let pattern = #"[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        for match in regex.matches(in: text, range: full) {
            out.addAttributes(
                [
                    .font: arFont,
                    .foregroundColor: arabicColor
                ],
                range: match.range
            )
        }
        return out
    }
}

// MARK: - Pinch zoom (iPhone + iPad)

/// Scroll view that yields the left-edge pan to the nav interactive-pop gesture
/// without replacing UIScrollView's internal pan-gesture delegate (that crashed).
private final class EdgeAwareScrollView: UIScrollView {
    /// Left-edge width that prefers system back-swipe over scrolling.
    var edgeBackWidth: CGFloat = 28

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let loc = gestureRecognizer.location(in: self)
            let vel = panGestureRecognizer.velocity(in: self)
            if loc.x < edgeBackWidth,
               abs(vel.x) >= abs(vel.y),
               vel.x > 0,
               contentOffset.x <= 0.5 {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

/// UIScrollView-backed pinch zoom for long reading content.
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    var minZoom: CGFloat = 1
    var maxZoom: CGFloat = 3
    var initialOffsetY: CGFloat = 0
    var onOffsetChange: ((CGFloat) -> Void)? = nil
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChange: onOffsetChange)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = EdgeAwareScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = minZoom
        scroll.maximumZoomScale = maxZoom
        scroll.bouncesZoom = true
        scroll.alwaysBounceVertical = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = true
        scroll.backgroundColor = .clear
        scroll.contentInsetAdjustmentBehavior = .automatic
        // Do NOT replace panGestureRecognizer.delegate — UIScrollView owns it.

        let host = UIHostingController(rootView: content())
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        scroll.addSubview(host.view)
        context.coordinator.host = host
        context.coordinator.scrollView = scroll

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        if initialOffsetY > 0 {
            DispatchQueue.main.async {
                scroll.setContentOffset(CGPoint(x: 0, y: initialOffsetY), animated: false)
            }
        }

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.onOffsetChange = onOffsetChange
        context.coordinator.host?.rootView = content()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var host: UIHostingController<Content>?
        weak var scrollView: UIScrollView?
        var onOffsetChange: ((CGFloat) -> Void)?
        private var lastReported: CGFloat = -1

        init(onOffsetChange: ((CGFloat) -> Void)?) {
            self.onOffsetChange = onOffsetChange
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            host?.view
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let y = scrollView.contentOffset.y
            if abs(y - lastReported) > 40 {
                lastReported = y
                onOffsetChange?(y)
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = scrollView else { return }
            if scroll.zoomScale > scroll.minimumZoomScale + 0.01 {
                scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
            } else {
                let target = min(scroll.maximumZoomScale, 1.75)
                let point = gesture.location(in: host?.view)
                let size = scroll.bounds.size
                let w = size.width / target
                let h = size.height / target
                let rect = CGRect(
                    x: point.x - w / 2,
                    y: point.y - h / 2,
                    width: w,
                    height: h
                )
                scroll.zoom(to: rect, animated: true)
            }
        }
    }
}

// MARK: - SwiftUI helpers

extension View {
    /// Enable system text selection / copy on SwiftUI `Text`.
    func beUmmatiSelectableText() -> some View {
        self.textSelection(.enabled)
    }
}
