import UIKit

/// 无地球键的编程键盘：三行符号 + QWERTY + 底行控制，数字页九宫格；
/// 成对补全/跳过右括号/成对退格；方向键/退格长按；空格左右滑移位；长按空格切换输入法；
/// 按键气泡预览。
final class KeyboardViewController: UIInputViewController {

    // MARK: - UI
    private let vStack = UIStackView()
    private var allButtons: [UIButton] = []
    private var popupViews: [UIButton: UIView] = [:]

    // 状态
    private var isSymbolMode = false   // false=字母页, true=数字页
    private var isUppercase = false    // Shift

    // 固定高度（让键更“矮胖”）
    private var heightConstraint: NSLayoutConstraint?

    // 长按连发
    private var repeatTimer: Timer?
    private var repeatAction: (() -> Void)?

    // 空格滑动移位
    private var spacePanStartX: CGFloat = 0
    private var spacePanAccum: CGFloat = 0
    private let pixelsPerMove: CGFloat = 18

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        reloadKeyboard()
    }

    // MARK: - 布局
    private func setupLayout() {
        view.backgroundColor = .systemGroupedBackground

        vStack.axis = .vertical
        vStack.alignment = .fill
        vStack.distribution = .fillEqually
        vStack.spacing = 6
        vStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vStack)

        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 8),
            vStack.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -8),
            vStack.topAnchor.constraint(equalTo: g.topAnchor, constant: 6),
            vStack.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -6)
        ])

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 300) // 字母页高度
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true
    }

    private func updateHeightForCurrentMode() {
        heightConstraint?.constant = isSymbolMode ? 280 : 300 // 数字页略低
        view.setNeedsLayout()
    }

    private func clearRows() {
        vStack.arrangedSubviews.forEach { vStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        allButtons.removeAll()
        popupViews.values.forEach { $0.removeFromSuperview() }
        popupViews.removeAll()
    }

    private func reloadKeyboard() {
        clearRows()
        if isSymbolMode {
            buildNumberPadLayout()
        } else {
            buildLettersLayout()
        }
        updateHeightForCurrentMode()
    }

    // MARK: - 字母页：三行符号 + QWERTY
    private func buildLettersLayout() {
        // 符号三行（更松散，键会略小）
        let symRow1: [KeyKind] = [.tab, .char("!"), .char("#"), .char("%"), .char("^"), .char("&"), .char("*"), .char(".")]
        let symRow2: [KeyKind] = [.char(","), .char(";"), .char("|"), .char(":"), .char("/"), .char("\\"), .char("\""), .char("'")]
        let symRow3: [KeyKind] = [.char("("), .char(")"), .char("<"), .char(">"), .char("{"), .char("}"), .char("["), .char("]")]

        vStack.addArrangedSubview(makeRow(symRow1))
        vStack.addArrangedSubview(makeRow(symRow2))
        vStack.addArrangedSubview(makeRow(symRow3))

        // QWERTY 三行（键更大）
        let r1 = "qwertyuiop"
        let r2 = "asdfghjkl"
        let r3 = "zxcvbnm"

        vStack.addArrangedSubview(makeRow(r1.map { .letter(String($0)) }))
        vStack.addArrangedSubview(makeRow(r2.map { .letter(String($0)) }))

        var third: [KeyKind] = [.shift]
        third += r3.map { .letter(String($0)) }
        third.append(.backspace)
        vStack.addArrangedSubview(makeRow(third))

        // 底行：123 / ← 空格 → / Return
        let bottom: [KeyKind] = [.mode123, .cursorLeft, .space, .cursorRight, .returnKey]
        vStack.addArrangedSubview(makeRow(bottom))

        applyCase()
    }

    // MARK: - 数字页：九宫格
    private func buildNumberPadLayout() {
        let r1: [KeyKind] = ["1","2","3"].map { .char($0) }
        let r2: [KeyKind] = ["4","5","6"].map { .char($0) }
        let r3: [KeyKind] = ["7","8","9"].map { .char($0) }
        vStack.addArrangedSubview(makeRow(r1))
        vStack.addArrangedSubview(makeRow(r2))
        vStack.addArrangedSubview(makeRow(r3))

        // 底行：ABC / ← 0 → / ⌫ Return
        let r4: [KeyKind] = [.modeABC, .cursorLeft, .char("0"), .cursorRight, .backspace, .returnKey]
        vStack.addArrangedSubview(makeRow(r4))
    }

    // MARK: - Key & Row
    private enum KeyKind {
        case letter(String)          // 受大小写控制（字母键：更大）
        case char(String)            // 符号/数字键（略小）
        case tab                     // 显示为 →
        case backspace, space, returnKey
        case shift
        case mode123, modeABC
        case cursorLeft, cursorRight
    }

    private func makeRow(_ keys: [KeyKind]) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .fill
        row.distribution = .fillEqually
        row.spacing = 3

        for k in keys {
            let b = UIButton(type: .system)
            style(b, kind: k)

            // —— 按键气泡：字母/符号/Tab 显示 —— //
            let needsPopup: Bool = {
                switch k { case .letter, .char, .tab: return true; default: return false }
            }()

            func bindPopup(title: String) {
                if needsPopup {
                    b.addAction(UIAction { [weak self, weak b] _ in
                        guard let self, let btn = b else { return }
                        self.showPopup(for: btn, text: title)
                    }, for: .touchDown)

                    [UIControl.Event.touchDragExit, .touchCancel, .touchUpOutside].forEach { ev in
                        b.addAction(UIAction { [weak self, weak b] _ in
                            guard let self, let btn = b else { return }
                            self.hidePopup(for: btn)
                        }, for: ev)
                    }

                    b.addAction(UIAction { [weak self, weak b] _ in
                        guard let self, let btn = b else { return }
                        self.showPopup(for: btn, text: title)
                    }, for: .touchDragEnter)
                }
            }

            switch k {
            case .letter(let s):
                let title = applyCase(to: s)
                bindPopup(title: title)
                b.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    self.hidePopup(for: b)
                    self.handleChar(self.applyCase(to: s))
                }, for: .touchUpInside)

            case .char(let s):
                bindPopup(title: s)
                b.addAction(UIAction { [weak self] _ in
                    self?.hidePopup(for: b)
                    self?.handleChar(s)
                }, for: .touchUpInside)

            case .tab:
                bindPopup(title: "→")
                b.addAction(UIAction { [weak self] _ in
                    self?.hidePopup(for: b)
                    self?.textDocumentProxy.insertText("\t")
                    self?.lightHaptic()
                }, for: .touchUpInside)

            case .backspace:
                addRepeatableAction(to: b,
                    down: { [weak self] in self?.handleBackspace() },
                    repeatBlock: { [weak self] in self?.handleBackspace() })

            case .space:
                b.addAction(UIAction { [weak self] _ in
                    self?.textDocumentProxy.insertText(" ")
                    self?.lightHaptic()
                }, for: .touchUpInside)
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSpacePan(_:)))
                pan.maximumNumberOfTouches = 1
                b.addGestureRecognizer(pan)
                let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleSpaceLongPress(_:)))
                b.addGestureRecognizer(lp)

            case .returnKey:
                b.addAction(UIAction { [weak self] _ in
                    self?.textDocumentProxy.insertText("\n")
                    self?.lightHaptic()
                }, for: .touchUpInside)

            case .shift:
                b.addAction(UIAction { [weak self, weak b] _ in
                    guard let self else { return }
                    self.isUppercase.toggle()
                    self.applyCase()
                    self.bump(b)
                }, for: .touchUpInside)

            case .mode123:
                b.addAction(UIAction { [weak self] _ in
                    self?.isSymbolMode = true
                    self?.reloadKeyboard()
                }, for: .touchUpInside)

            case .modeABC:
                b.addAction(UIAction { [weak self] _ in
                    self?.isSymbolMode = false
                    self?.reloadKeyboard()
                }, for: .touchUpInside)

            case .cursorLeft:
                addRepeatableAction(to: b,
                    down: { [weak self] in self?.moveCursor(-1) },
                    repeatBlock: { [weak self] in self?.moveCursor(-1) })

            case .cursorRight:
                addRepeatableAction(to: b,
                    down: { [weak self] in self?.moveCursor(1) },
                    repeatBlock: { [weak self] in self?.moveCursor(1) })
            }

            allButtons.append(b)
            row.addArrangedSubview(b)
        }
        return row
    }

    // 统一在这里细分“字母/符号/控制键”的字号与内边距
    private func style(_ button: UIButton, kind: KeyKind) {
        // 标题
        var title: String = ""
        switch kind {
        case .letter(let s):  title = applyCase(to: s)
        case .char(let s):    title = s
        case .tab:            title = "→"
        case .backspace:      title = "⌫"
        case .space:          title = "  "   // ← 改为“空格”
        case .returnKey:      title = "Return"
        case .shift:          title = isUppercase ? "⇪" : "⇧"
        case .mode123:        title = "123"
        case .modeABC:        title = "ABC"
        case .cursorLeft:     title = "←"
        case .cursorRight:    title = "→"
        }

        // 风格参数（按类型区分）
        let fontSize: CGFloat
        let insets: NSDirectionalEdgeInsets

        switch kind {
        case .letter:
            // 原来大概是 fontSize = 21, insets (top:10, leading:14, bottom:10, trailing:14)
            fontSize = 19
            insets = NSDirectionalEdgeInsets(top: 9, leading: 6, bottom: 9, trailing: 6)
        case .char, .tab:
            // 原来 17 / (6,10,6,10)
            fontSize = 16
            insets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        case .space:
            fontSize = 17
            insets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        case .returnKey:
            // Return 再小一点
            fontSize = 15
            insets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        case .backspace, .cursorLeft, .cursorRight:
            fontSize = 18
            insets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        case .shift, .mode123, .modeABC:
            fontSize = 12
            insets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        }

        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = .secondarySystemFill
        config.baseForegroundColor = .label
        config.cornerStyle = .large
        config.contentInsets = insets
        button.configuration = config
        button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
    }

    // MARK: - 按键气泡
    private func showPopup(for button: UIButton, text: String) {
        if let exist = popupViews[button] as? UILabel {
            exist.text = text
            return
        }
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 26, weight: .semibold) // 略小一点
        label.textAlignment = .center
        label.textColor = .label
        label.backgroundColor = .systemBackground
        label.layer.cornerRadius = 10
        label.layer.borderWidth = 0.5
        label.layer.borderColor = UIColor.separator.cgColor
        label.clipsToBounds = true
        label.sizeToFit()

        let pad: CGFloat = 12
        let w = max(44, label.bounds.width + pad * 2)
        let h: CGFloat = 50  // 比之前略矮
        label.frame = CGRect(x: 0, y: 0, width: w, height: h)

        let rect = button.convert(button.bounds, to: view)
        var x = rect.midX - w / 2
        var y = rect.minY - h - 6
        x = max(4, min(x, view.bounds.width - w - 4))
        y = max(2, y)

        label.frame.origin = CGPoint(x: x, y: y)
        view.addSubview(label)
        popupViews[button] = label
    }

    private func hidePopup(for button: UIButton) {
        if let v = popupViews.removeValue(forKey: button) { v.removeFromSuperview() }
    }

    // MARK: - 大小写应用
    private func applyCase() {
        for b in allButtons {
            guard var t = b.configuration?.title, !t.isEmpty else { continue }
            if t.count == 1, let ch = t.first, ch.isLetter {
                t = applyCase(to: t)
                b.configuration?.title = t
            } else if t == "⇧" || t == "⇪" {
                b.configuration?.title = isUppercase ? "⇪" : "⇧"
            }
        }
    }
    private func applyCase(to s: String) -> String { isUppercase ? s.uppercased() : s.lowercased() }

    private func bump(_ button: UIButton?) {
        guard let v = button else { return }
        UIView.animate(withDuration: 0.08, animations: {
            v.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        }) { _ in
            UIView.animate(withDuration: 0.08) { v.transform = .identity }
        }
    }

    // MARK: - 文本逻辑（成对/越过/退格）
    private let pairMap: [Character: Character] = [
        "(": ")", "{": "}", "[": "]", "<": ">", "\"": "\"", "'": "'"
    ]
    private var pairOpeners: Set<Character> { Set(pairMap.keys) }
    private var pairClosers: Set<Character> { Set(pairMap.values) }

    private func handleChar(_ s: String) {
        if s.count > 1 { textDocumentProxy.insertText(s); lightHaptic(); return }
        let ch = s.first!
        if ch.isLetter { textDocumentProxy.insertText(applyCase(to: String(ch))); lightHaptic(); return }

        let after = textDocumentProxy.documentContextAfterInput?.first

        if pairOpeners.contains(ch) {
            let closing = pairMap[ch]!
            if let a = after, a.isLetter || a.isNumber {
                textDocumentProxy.insertText(String(ch))
            } else {
                textDocumentProxy.insertText(String([ch, closing]))
                textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
            }
            lightHaptic(); return
        }

        if pairClosers.contains(ch) {
            if after == ch { textDocumentProxy.adjustTextPosition(byCharacterOffset: 1) }
            else { textDocumentProxy.insertText(String(ch)) }
            lightHaptic(); return
        }

        textDocumentProxy.insertText(String(ch))
        lightHaptic()
    }

    private func handleBackspace() {
        let before = textDocumentProxy.documentContextBeforeInput?.last
        let after  = textDocumentProxy.documentContextAfterInput?.first
        if let b = before, let expected = pairMap[b], after == expected {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            textDocumentProxy.deleteBackward()
            lightHaptic(); return
        }
        textDocumentProxy.deleteBackward()
        lightHaptic()
    }

    private func moveCursor(_ delta: Int) {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: delta)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
    }

    // MARK: - 长按连发
    private func addRepeatableAction(to button: UIButton, down: @escaping () -> Void, repeatBlock: @escaping () -> Void) {
        button.addAction(UIAction { [weak self] _ in
            down()
            self?.startRepeat(repeatBlock)
        }, for: .touchDown)

        let end: UIActionHandler = { [weak self] _ in self?.stopRepeat() }
        [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit].forEach { ev in
            button.addAction(UIAction(handler: end), for: ev)
        }
    }

    private func startRepeat(_ action: @escaping () -> Void) {
        stopRepeat()
        repeatAction = action
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in action() }
        }
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatAction = nil
    }

    // MARK: - 空格滑动 & 长按切换输入法
    @objc private func handleSpacePan(_ g: UIPanGestureRecognizer) {
        let p = g.translation(in: g.view)
        switch g.state {
        case .began: spacePanStartX = p.x; spacePanAccum = 0
        case .changed:
            let dx = p.x - spacePanStartX
            spacePanAccum += dx
            spacePanStartX = p.x
            let steps = Int(spacePanAccum / pixelsPerMove)
            if steps != 0 {
                moveCursor(steps)
                spacePanAccum -= CGFloat(steps) * pixelsPerMove
            }
        default: spacePanAccum = 0
        }
    }

    @objc private func handleSpaceLongPress(_ g: UILongPressGestureRecognizer) {
        if g.state == .began { advanceToNextInputMode() }
    }

    // MARK: - 外观
    private func lightHaptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        let style = textDocumentProxy.keyboardAppearance ?? .default
        view.backgroundColor = (style == .dark) ? .secondarySystemBackground : .systemGroupedBackground
    }
}
