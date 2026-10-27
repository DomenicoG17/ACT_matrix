import UIKit

/// This is the native iOS keyboard accessory: it stays directly ABOVE the keyboard.
final class MatrixKeyboardBar: UIView {
    var onNavigate: ((Int) -> Void)?
    var onNew: (() -> Void)?

    private var quadrantButtons: [UIButton] = []
    private var currentQuadrant: Int

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 70)
    }

    init(currentQuadrant: Int) {
        self.currentQuadrant = currentQuadrant
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 70))
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
        newButton.setTitle("  Nuova", for: .normal)
        newButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        newButton.tintColor = .label
        newButton.contentHorizontalAlignment = .leading
        newButton.accessibilityLabel = "Crea nuova matrice ACT"
        newButton.addTarget(self, action: #selector(createNew), for: .touchUpInside)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let caption = UILabel()
        caption.text = "VAI A"
        caption.textColor = .secondaryLabel
        caption.font = .systemFont(ofSize: 10, weight: .semibold)

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 3
        for row in 0..<2 {
            let line = UIStackView()
            line.axis = .horizontal
            line.spacing = 3
            for column in 0..<2 {
                let quadrant = row * 2 + column
                let button = UIButton(type: .custom)
                button.tag = quadrant
                button.layer.cornerRadius = 5
                button.layer.borderWidth = 1
                button.translatesAutoresizingMaskIntoConstraints = false
                button.widthAnchor.constraint(equalToConstant: 28).isActive = true
                button.heightAnchor.constraint(equalToConstant: 28).isActive = true
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

        let row = UIStackView(arrangedSubviews: [newButton, spacer, caption, grid])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -22),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.heightAnchor.constraint(equalToConstant: 60),
            newButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])
        selectQuadrant(currentQuadrant)
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

    @objc private func navigate(_ sender: UIButton) { onNavigate?(sender.tag) }
    @objc private func createNew() { onNew?() }
}
