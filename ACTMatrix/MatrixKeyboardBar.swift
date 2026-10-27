import UIKit

/// A compact native accessory that follows the iOS keyboard.
/// Upper row: [💭 🎇 🏞️ 🔲]. Lower row: [New] [show all CENTERED] [2x2].
final class MatrixKeyboardBar: UIView {
    var onNavigate: ((Int) -> Void)?
    var onNew: (() -> Void)?
    var onShowAll: (() -> Void)?
    var onChooseKind: ((ACTEntryKind) -> Void)?
    var onIndent: ((Int) -> Void)?

    private var quadrantButtons: [UIButton] = []
    private var kindButtons: [ACTEntryKind: UIButton] = [:]
    private var currentQuadrant: Int
    private var selectedKind: ACTEntryKind = .bullet

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 94)
    }

    init(currentQuadrant: Int) {
        self.currentQuadrant = currentQuadrant
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 94))
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        let rule = UIView()
        rule.backgroundColor = .separator
        rule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rule)
        NSLayoutConstraint.activate([
            rule.topAnchor.constraint(equalTo: topAnchor),
            rule.leadingAnchor.constraint(equalTo: leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor),
            rule.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        let newButton = UIButton(type: .system)
        newButton.setImage(UIImage(systemName: "plus.square.on.square"), for: .normal)
        newButton.tintColor = .label
        newButton.accessibilityLabel = "Crea una nuova matrice vuota"
        newButton.addTarget(self, action: #selector(createNew), for: .touchUpInside)
        newButton.translatesAutoresizingMaskIntoConstraints = false
        newButton.widthAnchor.constraint(equalToConstant: 34).isActive = true
        newButton.heightAnchor.constraint(equalToConstant: 42).isActive = true

        let types = UIStackView()
        types.axis = .horizontal
        types.alignment = .center
        types.distribution = .fillEqually
        types.spacing = 2
        for kind in ACTEntryKind.allCases where kind != .bullet {
            let button = UIButton(type: .system)
            button.setTitle(kind.symbol, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 21)
            button.layer.cornerRadius = 7
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.clear.cgColor
            button.accessibilityLabel = "Tipo voce: \(kind.accessibilityName)"
            button.addTarget(self, action: #selector(chooseKind(_:)), for: .touchUpInside)
            button.tag = kindIndex(kind)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
            kindButtons[kind] = button
            types.addArrangedSubview(button)
        }

        let indent = UIButton(type: .system)
        indent.setTitle("↳", for: .normal)
        indent.titleLabel?.font = .systemFont(ofSize: 26, weight: .medium)
        indent.tintColor = .label
        indent.accessibilityLabel = "Rientra la voce, crea una sottovoce"
        indent.addTarget(self, action: #selector(indentTapped), for: .touchUpInside)
        indent.translatesAutoresizingMaskIntoConstraints = false
        let outdent = UIButton(type: .system)
        outdent.setTitle("⇤", for: .normal)
        outdent.titleLabel?.font = .systemFont(ofSize: 23, weight: .medium)
        outdent.tintColor = .secondaryLabel
        outdent.accessibilityLabel = "Riduci rientro della voce"
        outdent.addTarget(self, action: #selector(outdentTapped), for: .touchUpInside)
        outdent.translatesAutoresizingMaskIntoConstraints = false

        let showAllButton = UIButton(type: .system)
        showAllButton.setImage(UIImage(systemName: "square.grid.2x2"), for: .normal)
        showAllButton.tintColor = .label
        showAllButton.accessibilityLabel = "Mostra tutti e quattro i riquadri"
        showAllButton.addTarget(self, action: #selector(showAll), for: .touchUpInside)
        showAllButton.translatesAutoresizingMaskIntoConstraints = false
        showAllButton.widthAnchor.constraint(equalToConstant: 34).isActive = true
        showAllButton.heightAnchor.constraint(equalToConstant: 42).isActive = true

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 2
        for row in 0..<2 {
            let line = UIStackView()
            line.axis = .horizontal
            line.spacing = 2
            for column in 0..<2 {
                let quadrant = row * 2 + column
                let button = UIButton(type: .custom)
                button.tag = quadrant
                button.layer.cornerRadius = 5
                button.layer.borderWidth = 1
                button.translatesAutoresizingMaskIntoConstraints = false
                button.widthAnchor.constraint(equalToConstant: 26).isActive = true
                button.heightAnchor.constraint(equalToConstant: 26).isActive = true
                button.accessibilityLabel = [
                    "Azioni di allontanamento", "Azioni di avvicinamento",
                    "Pensieri ed emozioni", "Persone e valori"
                ][quadrant]
                button.addTarget(self, action: #selector(navigate(_:)), for: .touchUpInside)
                quadrantButtons.append(button)
                line.addArrangedSubview(button)
            }
            grid.addArrangedSubview(line)
        }

        // Two lightweight rows prevent crowding on narrow iPhones and keep the
        // show-all control geometrically CENTERED, as requested.
        for view in [types, newButton, showAllButton, grid, indent, outdent] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            types.centerXAnchor.constraint(equalTo: centerXAnchor),
            types.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            types.heightAnchor.constraint(equalToConstant: 38),
            outdent.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 18),
            outdent.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            outdent.widthAnchor.constraint(equalToConstant: 36),
            outdent.heightAnchor.constraint(equalToConstant: 38),
            indent.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -18),
            indent.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            indent.widthAnchor.constraint(equalToConstant: 36),
            indent.heightAnchor.constraint(equalToConstant: 38),

            newButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            newButton.centerYAnchor.constraint(equalTo: topAnchor, constant: 66),

            showAllButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            showAllButton.centerYAnchor.constraint(equalTo: topAnchor, constant: 66),

            grid.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -12),
            grid.centerYAnchor.constraint(equalTo: topAnchor, constant: 66)
        ])
        selectQuadrant(currentQuadrant)
        selectKind(.bullet)
    }

    private func kindIndex(_ kind: ACTEntryKind) -> Int {
        ACTEntryKind.allCases.firstIndex(of: kind) ?? 0
    }

    func selectKind(_ selected: ACTEntryKind) {
        selectedKind = selected
        for (kind, button) in kindButtons {
            let active = kind == selected
            button.layer.borderColor = (active ? UIColor.systemTeal : UIColor.clear).cgColor
            button.backgroundColor = active ? UIColor.systemTeal.withAlphaComponent(0.16) : .clear
        }
    }

    func selectQuadrant(_ selected: Int) {
        currentQuadrant = selected
        for button in quadrantButtons {
            let active = button.tag == selected
            button.layer.borderColor = (active ? UIColor.systemTeal : UIColor.tertiaryLabel)
                .withAlphaComponent(active ? 0.95 : 0.56).cgColor
            button.backgroundColor = active
                ? UIColor.systemTeal.withAlphaComponent(0.20)
                : UIColor.clear
        }
    }

    @objc private func indentTapped() { onIndent?(1) }
    @objc private func outdentTapped() { onIndent?(-1) }

    @objc private func chooseKind(_ sender: UIButton) {
        guard ACTEntryKind.allCases.indices.contains(sender.tag) else { return }
        let chosen = ACTEntryKind.allCases[sender.tag]
        // Tap an already-selected type to go back to a plain bullet.
        onChooseKind?(chosen == selectedKind ? .bullet : chosen)
    }
    @objc private func navigate(_ sender: UIButton) { onNavigate?(sender.tag) }
    @objc private func createNew() { onNew?() }
    @objc private func showAll() { onShowAll?() }
}
